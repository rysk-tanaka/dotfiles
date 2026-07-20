#!/usr/bin/env bash
# Codex のプラン使用制限を RunCat Neo カスタムメトリクス JSON へ変換する。
# launchd (com.rysk.runcat-codex-usage) が定期実行し ~/.runcat/codex-usage.json を更新、
# RunCat Neo (Settings > Metrics > Custom Metrics) がこのファイルを監視する。
#
# 取得は codex app-server の JSON-RPC (account/rateLimits/read) 経由。認証は codex 本体が
# ~/.codex/auth.json で解決するため、このスクリプトはアクセストークンを一切扱わない。
# rollout JSONL を読む案は codex exec 実行分の rate_limits が null になる不具合があり、
# /api/codex/usage を直接叩く案はトークンの取り回しが必要になるため、どちらも採らない。
#
# app-server は experimental 扱いでメソッド名や応答形式が予告なく変わりうる。codex 未導入・
# 応答形式の変更・サインアウトのいずれでも launchd ジョブを壊さないよう、失敗時は既存
# キャッシュへ、それも無ければ空メトリクスへ縮退して必ず正常終了する。
set -euo pipefail

OUT="${RUNCAT_JSON:-$HOME/.runcat/codex-usage.json}"
OUT_DIR="$(dirname "$OUT")"
# 縮退動作を検証する時だけ失敗するコマンドに差し替えられるようにしておく。
CODEX_BIN="${CODEX_BIN:-codex}"
CACHE="$OUT_DIR/.codex-usage-api.json"
# codex を使っていない間も直近の消費率を表示し続けるためのキャッシュ。ただし古すぎる値は
# 「今の消費率」として誤解を招くので上限を設ける。
CACHE_MAX_AGE=3600

mkdir -p "$OUT_DIR"

api_tmp=""
out_tmp=""
trap 'rm -f "$api_tmp" "$out_tmp"' EXIT

metrics=""
bar=""

# rateLimits 応答をメトリクス行とバー文字列へ変換する。フィールド欠落やウィンドウ構成の変更で
# jq は失敗しうるので、変換できた時だけ metrics/bar を設定し、それ以外は非ゼロを返して呼び出し
# 側の縮退分岐に委ねる。
# 行は応答の形から組み立てる。ChatGPT Plus では primary が週間枠のみで secondary は null だが、
# プラン変更で 5 時間枠が増えても壊れないよう windowDurationMins からラベルを引く。
# rateLimitsByLimitId には limitId が rateLimits と同じ全体枠とモデル別枠が混在するので、
# 全体枠は rateLimits 側と重複するため除外する。
transform_usage() {
  local json="$1" m b
  m="$(jq -c '
    def window_label($mins):
      if $mins == 10080 then "週間"
      elif $mins == 300 then "5時間"
      else "\($mins / 60 | floor)h枠" end;

    # resetsAt は epoch 秒。過去になった枠は「残 0」に丸める。
    def left_str($resets):
      (($resets - now) | if . < 0 then 0 else . end) as $left
      | if $left >= 86400
        then "(残 \($left / 86400 | floor)d\(($left % 86400) / 3600 | floor)h)"
        else "(残 \($left / 3600 | floor)h\((($left % 3600) / 60 | floor) | tostring | if length < 2 then "0" + . else . end)m)"
        end;

    def limit_row($entry; $title):
      { title: $title,
        formattedValue: "\($entry.usedPercent)% " + left_str($entry.resetsAt),
        normalizedValue: ($entry.usedPercent / 100) };

    .rateLimits.limitId as $main
    | [ ( .rateLimits | (.primary, .secondary) | select(. != null)
          | limit_row(.; window_label(.windowDurationMins)) ),
        ( .rateLimitsByLimitId // {} | to_entries[] | .value
          | select(.limitId != $main and .limitName != null and .primary != null)
          # ウィンドウが一度も開始していない枠を落とす。未使用の枠は resetsAt が照会のたびに
          # 前進して常に「今 + ウィンドウ長」を返すため、残り時間がウィンドウ長とほぼ同じかで
          # 判別できる。12 分空けて 2 回照会し、メイン枠の resetsAt が固定される一方でモデル別
          # 枠が経過時間ぶん前進することを実測した。300 秒の余裕はサーバーとの時計ずれの吸収用
          # で、開始直後の枠が数分隠れるが、その時点の値に情報は無い。
          # これが無いと GPT-5.3-Codex-Spark の枠が 0% のまま並び続ける。この枠は実使用でも
          # 加算されない不具合が報告されており (https://github.com/openai/codex/issues/23150)、
          # 未使用なのか集計漏れなのかは区別できないが、どちらでも表示する価値が無い。
          | select(.primary.resetsAt - now < .primary.windowDurationMins * 60 - 300)
          | limit_row(.primary; "\(window_label(.primary.windowDurationMins)) (\(.limitName))") ),
        ( .rateLimitResetCredits.availableCount
          | select(. != null)
          # 使用率ではなく個数なので、バーを伸ばさないよう normalizedValue は 0 で固定する。
          | { title: "リセット権", formattedValue: "\(.)", normalizedValue: 0 } )
      ]
    # 応答から 1 行も作れない場合、そのまま採用すると空のカードでキャッシュを潰してしまう。
    | if length == 0 then error("no rate limit entries") else . end' \
    <<<"$json" 2>/dev/null)" || return 1
  # 数値であることまで確かめる。欠落時に "null%" と表示するより ---  へ縮退した方がよい。
  b="$(jq -r '.rateLimits.primary.usedPercent | select(type == "number") | "\(.)%"' \
    <<<"$json" 2>/dev/null)" || return 1
  [[ -n "$m" && -n "$b" ]] || return 1
  metrics="$m"
  bar="$b"
}

# app-server を実行時間の上限付きで起動する。上限が要るのは、後続の sleep が閉じるのは stdin
# だけで、app-server が OpenAI の usage API を待って返さない限りパイプラインが終わらないため。
# launchd は前回の実行が生きている間 StartInterval の次回分を起動しないので、一度ハングすると
# 手動で kill するまで表示が固まったままになる。姉妹スクリプトの curl -m 10 と同じ役割。
# timeout は Brewfile の coreutils 由来。現行の 9.11 は timeout と gtimeout の両方を配置するが、
# 古い環境では g 付きしか無いことがあるので両対応する。どちらも無ければ上限なしで実行する。
# ここで諦めると使用率が二度と更新されず、呼び出し側の || true に握り潰されて気付けないため。
run_app_server() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 15 "$CODEX_BIN" app-server
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout 15 "$CODEX_BIN" app-server
  else
    "$CODEX_BIN" app-server
  fi
}

if command -v "$CODEX_BIN" >/dev/null 2>&1; then
  api_tmp="$(mktemp "$OUT_DIR/.codex-usage-api.XXXXXX")"
  # initialize から本リクエストまでを続けて流し込み、sleep で応答を受け取ってから stdin を閉じる。
  # app-server は stdin の EOF で終了するため、この sleep がプロセスを残さないための仕組みも
  # 兼ねる。応答が 2 秒に間に合わなければ空になり、下のキャッシュ縮退へ落ちる。再試行はしない。
  # initialized は codex 0.144.6 では省いても応答が返るが、プロトコル定義 (ClientNotification の
  # InitializedNotification) では initialize に続けて送ることになっている。将来のバージョンが
  # 未送信を拒否しても壊れないよう仕様どおりに送る。
  { printf '%s\n%s\n%s\n' \
      '{"method":"initialize","id":0,"params":{"clientInfo":{"name":"runcat-codex-usage","title":"RunCat","version":"1.0"}}}' \
      '{"method":"initialized"}' \
      '{"method":"account/rateLimits/read","id":1,"params":{}}'
    sleep 2
  } | run_app_server 2>/dev/null \
    | jq -c 'select(.id == 1) | .result' > "$api_tmp" 2>/dev/null || true

  # 実際にメトリクスへ変換できるところまで確認してからキャッシュを置き換える。応答の形を
  # 部分的にしか見ずに採用すると、形式が変わった応答で正常なキャッシュを潰してしまい、
  # 冒頭に書いた「形式変更時は既存キャッシュへ縮退」が働かなくなるため。
  if transform_usage "$(cat "$api_tmp" 2>/dev/null)"; then
    mv "$api_tmp" "$CACHE"
  fi
fi

# 取得できなかった時だけキャッシュに頼る。存在確認は stat 自体に兼ねさせる。-f で確認して
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
out_tmp="$(mktemp "$OUT_DIR/.codex-usage.XXXXXX")"
if ! jq -n \
  --arg bar "$bar" \
  --argjson metrics "$metrics" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    title: "Codex usage",
    symbol: "terminal.fill",
    metricsBarValue: $bar,
    metrics: $metrics,
    lastUpdatedDate: $date
  }' > "$out_tmp" 2>/dev/null; then
  # jq が mise のバージョン切り替え等で引けなくなった場合でも表示を止めない。
  # 埋め込むのはリテラルと date の出力だけなので、jq 無しでもエスケープを気にせず書ける。
  printf '{"title":"Codex usage","symbol":"terminal.fill","metricsBarValue":"---","metrics":[],"lastUpdatedDate":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$out_tmp"
fi
mv "$out_tmp" "$OUT"
