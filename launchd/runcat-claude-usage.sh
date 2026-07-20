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
OUT_DIR="$(dirname "$OUT")"
# 縮退動作を検証する時だけ到達不能な URL に差し替えられるようにしておく。
USAGE_API_URL="${USAGE_API_URL:-https://api.anthropic.com/api/oauth/usage}"
CACHE="$OUT_DIR/.claude-usage-api.json"
# 429 は Retry-After を返さず数十分続くことがある。その間は直近の値で代替するが、
# 古すぎる値は「今の消費率」として誤解を招くので上限を設ける。
CACHE_MAX_AGE=3600

mkdir -p "$OUT_DIR"

api_tmp=""
out_tmp=""
trap 'rm -f "$api_tmp" "$out_tmp"' EXIT

metrics=""
bar=""

# usage JSON をメトリクス行とバー文字列へ変換する。要素のフィールド欠落や resets_at の
# オフセット変更で jq は失敗しうるので、変換できた時だけ metrics/bar を設定し、それ以外は
# 非ゼロを返して呼び出し側の縮退分岐に委ねる。
# resets_at はマイクロ秒と +00:00 オフセット付き (2026-07-25T18:00:00.002230+00:00) で、
# fromdateiso8601 が期待する %Y-%m-%dT%H:%M:%SZ に合わないため両方を落としてから渡す。
transform_usage() {
  local json="$1" m b
  m="$(jq -c '
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
    ]' <<<"$json" 2>/dev/null)" || return 1
  b="$(jq -r 'first(.limits[] | select(.kind == "session") | "\(.percent)%") // "---"' \
    <<<"$json" 2>/dev/null)" || return 1
  [[ -n "$m" && -n "$b" ]] || return 1
  metrics="$m"
  bar="$b"
}

# アクセストークンは Claude Code が Keychain に保存し、ログイン中は自動更新される。
# 値を画面にもログにも出さないよう、set -x を入れず curl の -v も使わない。
token="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)" || token=""

if [[ -n "$token" ]]; then
  api_tmp="$(mktemp "$OUT_DIR/.usage-api.XXXXXX")"
  # Authorization は -H ではなく stdin の設定ファイルとして -K - で渡す。-H だとトークンが
  # curl の argv に載り、同一ユーザーの他プロセスから ps で読めてしまうため。
  http_code="$(printf 'header = "Authorization: Bearer %s"\n' "$token" \
    | curl -sS -m 10 -K - -o "$api_tmp" -w '%{http_code}' \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "Content-Type: application/json" \
      "$USAGE_API_URL" 2>/dev/null)" || http_code="000"

  # 実際にメトリクスへ変換できるところまで確認してからキャッシュを置き換える。応答の形を
  # 部分的にしか見ずに採用すると、要素側の形式が変わった応答で正常なキャッシュを潰してしまい、
  # 冒頭に書いた「API 変更時は既存キャッシュへ縮退」が働かなくなるため。
  if [[ "$http_code" == "200" ]] && transform_usage "$(cat "$api_tmp" 2>/dev/null)"; then
    mv "$api_tmp" "$CACHE"
  fi
fi

# API から取れなかった時だけキャッシュに頼る。存在確認は stat 自体に兼ねさせる。-f で確認して
# から stat を呼ぶと、その間にキャッシュが消えた場合に stat が空を返し、算術展開が構文エラーに
# なって set -e で止まってしまう。
if [[ -z "$metrics" ]]; then
  cache_mtime="$(stat -f %m "$CACHE" 2>/dev/null || echo 0)"
  if (( cache_mtime > 0 )) && (( $(date +%s) - cache_mtime <= CACHE_MAX_AGE )); then
    transform_usage "$(cat "$CACHE" 2>/dev/null)" || true
  fi
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
out_tmp="$(mktemp "$OUT_DIR/.claude-usage.XXXXXX")"
if ! jq -n \
  --arg bar "$bar" \
  --argjson metrics "$metrics" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    title: "Claude Code usage",
    symbol: "brain.filled.head.profile",
    metricsBarValue: $bar,
    metrics: $metrics,
    lastUpdatedDate: $date
  }' > "$out_tmp" 2>/dev/null; then
  # jq が mise のバージョン切り替え等で引けなくなった場合でも表示を止めない。
  # 埋め込むのはリテラルと date の出力だけなので、jq 無しでもエスケープを気にせず書ける。
  printf '{"title":"Claude Code usage","symbol":"brain.filled.head.profile","metricsBarValue":"---","metrics":[],"lastUpdatedDate":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$out_tmp"
fi
mv "$out_tmp" "$OUT"
