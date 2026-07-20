#!/usr/bin/env bash
# Claude のプラン使用制限を RunCat Neo カスタムメトリクス JSON へ変換する。
# launchd (com.rysk.runcat-claude-usage) が定期実行し ~/.runcat/claude-usage.json を更新、
# RunCat Neo (Settings > Metrics > Custom Metrics) がこのファイルを監視する。
#
# 取得元は Claude Code の /usage コマンドと同じ非公開 API のため、レスポンス形式が予告なく
# 変わりうる。トークン失効・API 変更・429 のいずれでも launchd ジョブを壊さないよう、
# 失敗時は既存キャッシュへ、それも無ければ空メトリクスへ縮退して必ず正常終了する。
# キャッシュは未ログイン等でトークンが取れない時にも使うため、直近 1 時間は値が残る。
set -euo pipefail

OUT="${RUNCAT_JSON:-$HOME/.runcat/claude-usage.json}"
# 縮退動作を検証する時だけ到達不能な URL に差し替えられるようにしておく。
USAGE_API_URL="${USAGE_API_URL:-https://api.anthropic.com/api/oauth/usage}"
CACHE="$(dirname "$OUT")/.claude-usage-api.json"
# 429 は Retry-After を返さず数十分続くことがある。その間は直近の値で代替するが、
# 古すぎる値は「今の消費率」として誤解を招くので上限を設ける。
CACHE_MAX_AGE=3600

mkdir -p "$(dirname "$OUT")"

api_tmp=""
out_tmp=""
trap 'rm -f "$api_tmp" "$out_tmp"' EXIT

# アクセストークンは Claude Code が Keychain に保存し、ログイン中は自動更新される。
# 値を画面にもログにも出さないよう、set -x を入れず curl の -v も使わない。
token="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)" || token=""

if [[ -n "$token" ]]; then
  api_tmp="$(mktemp "$(dirname "$OUT")/.usage-api.XXXXXX")"
  # Authorization は -H ではなく stdin の設定ファイルとして -K - で渡す。-H だとトークンが
  # curl の argv に載り、同一ユーザーの他プロセスから ps で読めてしまうため。
  http_code="$(printf 'header = "Authorization: Bearer %s"\n' "$token" \
    | curl -sS -m 10 -K - -o "$api_tmp" -w '%{http_code}' \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "Content-Type: application/json" \
      "$USAGE_API_URL" 2>/dev/null)" || http_code="000"

  # limits の存在まで確認してからキャッシュを更新する。API 形式が変わった時に
  # 壊れた応答で有効なキャッシュを潰さないため。
  if [[ "$http_code" == "200" ]] && jq -e '.limits | arrays' "$api_tmp" >/dev/null 2>&1; then
    mv "$api_tmp" "$CACHE"
  fi
fi

usage_json=""
if [[ -f "$CACHE" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE") ))
  if (( cache_age <= CACHE_MAX_AGE )); then
    usage_json="$(cat "$CACHE")"
  fi
fi

metrics=""
bar=""
if [[ -n "$usage_json" ]]; then
  # キャッシュ時のガードは .limits が配列かどうかしか見ていない。要素側のフィールドが
  # 欠けたり resets_at のオフセットが +00:00 以外に変わったりすると以下の jq は失敗するので、
  # set -e で落ちないよう失敗を捕捉し、下の縮退分岐へ合流させる。
  # resets_at はマイクロ秒と +00:00 オフセット付き (2026-07-25T18:00:00.002230+00:00) で、
  # fromdateiso8601 が期待する %Y-%m-%dT%H:%M:%SZ に合わないため両方を落としてから渡す。
  metrics="$(jq -c '
    [ .limits[]
      | (.resets_at | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) as $reset
      | (($reset - now) | if . < 0 then 0 else . end) as $left
      | {
          title: (if .kind == "session" then "セッション"
                  elif .kind == "weekly_all" then "週間"
                  else "週間 (\(.scope.model.display_name // "モデル別"))" end),
          formattedValue: "\(.percent)% " + (
            if $left >= 86400
            then "(残 \($left / 86400 | floor)d\(($left % 86400) / 3600 | floor)h)"
            else "(残 \($left / 3600 | floor)h\((($left % 3600) / 60 | floor) | tostring | if length < 2 then "0" + . else . end)m)"
            end),
          normalizedValue: (.percent / 100)
        }
    ]' <<<"$usage_json" 2>/dev/null)" || metrics=""
  bar="$(jq -r 'first(.limits[] | select(.kind == "session") | "\(.percent)%") // "---"' \
    <<<"$usage_json" 2>/dev/null)" || bar=""
fi

# 取得もキャッシュ流用もできない、あるいは応答が想定の形でない状態。
# 空メトリクスにして異常を表示側で気付けるようにする。
if [[ -z "$metrics" || -z "$bar" ]]; then
  metrics="[]"
  bar="---"
fi

# キー名は RunCat Neo の Custom Metrics スキーマで固定。リネームすると無言で描画されなくなる。
# 書きかけの JSON を RunCat Neo が読まないよう、同一ディレクトリの一時ファイルへ書いて
# 公式スキーマドキュメントの Constraints が要求する作法に従い、mv で原子的に置換する。
out_tmp="$(mktemp "$(dirname "$OUT")/.claude-usage.XXXXXX")"
jq -n \
  --arg bar "$bar" \
  --argjson metrics "$metrics" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    title: "Claude Code usage",
    symbol: "brain.filled.head.profile",
    metricsBarValue: $bar,
    metrics: $metrics,
    lastUpdatedDate: $date
  }' > "$out_tmp"
mv "$out_tmp" "$OUT"
