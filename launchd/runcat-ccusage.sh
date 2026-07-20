#!/usr/bin/env bash
# ccusage の使用状況を RunCat Neo カスタムメトリクス JSON へ変換する。
# launchd (com.rysk.runcat-ccusage) が定期実行し ~/.runcat/ccusage.json を更新、
# RunCat Neo (Settings > Metrics > Custom Metrics) がこのファイルを監視する。
set -euo pipefail

OUT="${RUNCAT_JSON:-$HOME/.runcat/ccusage.json}"
mkdir -p "$(dirname "$OUT")"

today="$(date +%Y%m%d)"
month_start="$(date +%Y%m01)"

# daily / monthly はサブコマンド無しだと Codex 等の他エージェントも合算されるため claude で絞る。
# blocks (5時間セッションブロック) は Anthropic API 由来の概念で元々 Claude 専用のため、
# claude blocks と同じ値になる。トップレベルのまま使う。
daily_json="$(ccusage claude daily --json --since "$today")"
monthly_json="$(ccusage claude monthly --json --since "$month_start")"
block_json="$(ccusage blocks --active --json)"

d_cost="$(jq -r '.totals.totalCost // 0' <<<"$daily_json")"
d_tok="$(jq -r '.totals.totalTokens // 0' <<<"$daily_json")"
m_cost="$(jq -r '.totals.totalCost // 0' <<<"$monthly_json")"

# ブロック開始直後は projection / burnRate が null になるため、残り時間と経過率は
# 常に存在する startTime / endTime から自前で求める。burnRate は取れた時だけ使う。
block="$(jq -c '
  .blocks[0] // empty
  | select(.isActive and .costUSD != null)
  # fromdateiso8601 はミリ秒付き ISO8601 (.000Z) を strptime できないため事前に除去する。
  | (.startTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) as $start
  | (.endTime   | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) as $end
  | {
      cost: .costUSD,
      burn: (.burnRate.costPerHour // null),
      remaining_min: ((($end - now) / 60) | floor | if . < 0 then 0 else . end),
      elapsed: (((now - $start) / ($end - $start)) | if . < 0 then 0 elif . > 1 then 1 else . end)
    }' <<<"$block_json")"

# トークン数を 2.0M / 350K 形式に丸める。
fmt_tok() {
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000)  printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%.0fK", n/1000;
    else                printf "%d", n;
  }'
}

metrics="$(jq -n \
  --arg d_today "$(printf '$%.2f / %s tok' "$d_cost" "$(fmt_tok "$d_tok")")" \
  --arg d_month "$(printf '$%.2f' "$m_cost")" \
  '[{title: "今日", formattedValue: $d_today},
    {title: "今月", formattedValue: $d_month}]')"

# アクティブな5時間ブロックがある時だけ行を足す。バーはブロック経過率。
if [[ -n "$block" ]]; then
  b_cost="$(jq -r '.cost' <<<"$block")"
  b_remaining="$(jq -r '.remaining_min' <<<"$block")"
  b_burn="$(jq -r '.burn // empty' <<<"$block")"
  block_row="$(jq -n \
    --arg v "$(printf '$%.2f (残 %dh%02dm)' "$b_cost" $((b_remaining / 60)) $((b_remaining % 60)))" \
    --argjson n "$(jq -r '.elapsed' <<<"$block")" \
    '{title: "ブロック", formattedValue: $v, normalizedValue: $n}')"
  metrics="$(jq -n --argjson m "$metrics" --argjson b "$block_row" '$m + [$b]')"

  if [[ -n "$b_burn" ]]; then
    burn_row="$(jq -n --arg v "$(printf '$%.1f/h' "$b_burn")" '{title: "ペース", formattedValue: $v}')"
    metrics="$(jq -n --argjson m "$metrics" --argjson p "$burn_row" '$m + [$p]')"
  fi
fi

# キー名は RunCat Neo の Custom Metrics スキーマで固定。リネームすると無言で描画されなくなる。
# 書きかけの JSON を RunCat Neo が読まないよう、同一ディレクトリの一時ファイルへ書いて
# mv で原子的に置換する (公式スキーマドキュメントの Constraints で要求される作法)。
tmp="$(mktemp "$(dirname "$OUT")/.ccusage.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
jq -n \
  --arg bar "$(printf '$%.2f' "$d_cost")" \
  --argjson metrics "$metrics" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    title: "Claude Code usage",
    symbol: "brain.filled.head.profile",
    metricsBarValue: $bar,
    metrics: $metrics,
    lastUpdatedDate: $date
  }' > "$tmp"
mv "$tmp" "$OUT"
