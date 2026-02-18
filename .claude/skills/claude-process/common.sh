#!/bin/bash

# Common functions for Claude Code process management scripts

# Claude Code プロセスの PID を取得（Claude Desktop を除外）
# 2段階で検出する。
#   1. comm 完全一致: argv[0] が "claude" or "claude_code" のプロセス
#   2. comm が "node" かつ args に "claude-code" or "claude_code" を含むプロセス
#      （npm/node 環境で comm が "node" になるケース向け）
# comm を "node" に限定する理由: args パターンマッチだけでは、ps/awk/bash 等の
# プロセスが自身のコマンドライン引数にパターン文字列を含んで誤検出されるため。
# Claude Desktop は全プロセスの args に /Applications/Claude.app を含むため除外できる。
get_claude_processes() {
    ps -eo pid,comm,args 2>/dev/null | awk '
        $2 == "claude" || $2 == "claude_code" { print $1; next }
        $2 == "node" && /claude[-_]code/ && !/\/Applications\/Claude\.app/ { print $1 }
    ' || true
}

# エラーハンドリング関数
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# セッション保護用の PID リストを構築
# スクリプトの PID から祖先プロセスを辿り、保護対象をグローバル配列
# PROTECTED_PIDS に格納する。Claude Code から呼ばれた場合、プロセスツリー上の
# Claude Code 本体も保護される。
# 失敗時は非ゼロを返す（呼び出し元で処理を決定）
init_session_protection() {
    PROTECTED_PIDS=()
    local pid=$$
    local max_depth=10
    local depth=0

    while [ "$pid" -gt 1 ] && [ "$depth" -lt "$max_depth" ]; do
        PROTECTED_PIDS+=("$pid")
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -z "$pid" ]; then
            break
        fi
        depth=$((depth + 1))
    done

    # 自身の PID すら取得できなかった場合のみ失敗
    if [ "${#PROTECTED_PIDS[@]}" -eq 0 ]; then
        return 1
    fi

}

# Claude Desktop (Claude.app) 関連プロセスの PID を取得
# args に /Applications/Claude.app を含むプロセスを検出する
get_claude_desktop_processes() {
    ps -eo pid,args 2>/dev/null | awk '
        /\/Applications\/Claude\.app/ { print $1 }
    ' || true
}

# Claude Desktop と同時に起動された高CPU 関連プロセスを検出
# Claude Desktop の起動時刻 ±15秒以内に起動し、CPU > 50% のプロセスを返す
# Claude CLI / Claude Desktop 自身のプロセスは除外する
# 出力: "pid cpu" のペア（1行1プロセス）
get_companion_processes() {
    # Claude Desktop メインプロセスの PID を取得
    local desktop_pid
    desktop_pid=$(ps -eo pid,args 2>/dev/null | awk '/\/Applications\/Claude\.app\/Contents\/MacOS\/Claude$/ { print $1 }' | head -1)
    if [ -z "$desktop_pid" ]; then
        return 0
    fi

    # Claude Desktop の起動時刻をエポック秒に変換
    local desktop_lstart
    desktop_lstart=$(ps -o lstart= -p "$desktop_pid" 2>/dev/null | xargs)
    if [ -z "$desktop_lstart" ]; then
        return 0
    fi
    local desktop_epoch
    if [[ "$OSTYPE" == "darwin"* ]]; then
        desktop_epoch=$(date -j -f "%a %b %d %H:%M:%S %Y" "$desktop_lstart" +%s 2>/dev/null)
    else
        desktop_epoch=$(date -d "$desktop_lstart" +%s 2>/dev/null)
    fi
    if [ -z "$desktop_epoch" ]; then
        return 0
    fi

    # 除外対象の PID を収集（Claude CLI + Claude Desktop）
    local exclude_pids
    exclude_pids=$(get_claude_processes; get_claude_desktop_processes)

    # システム全体から高CPU プロセスを走査
    local time_window=15
    ps -eo pid,pcpu,lstart,comm 2>/dev/null | while read -r pid cpu _lstart_rest; do
        # ヘッダー行をスキップ
        [[ "$pid" == "PID" ]] && continue
        # CPU が 50% 以下はスキップ
        local cpu_int
        cpu_int=$(printf "%.0f" "$cpu" 2>/dev/null) || continue
        [ "$cpu_int" -le 50 ] && continue

        # 除外対象チェック
        if echo "$exclude_pids" | grep -qw "$pid"; then
            continue
        fi

        # 起動時刻を取得してエポック秒に変換
        local proc_lstart
        proc_lstart=$(ps -o lstart= -p "$pid" 2>/dev/null | xargs)
        [ -z "$proc_lstart" ] && continue
        local proc_epoch
        if [[ "$OSTYPE" == "darwin"* ]]; then
            proc_epoch=$(date -j -f "%a %b %d %H:%M:%S %Y" "$proc_lstart" +%s 2>/dev/null)
        else
            proc_epoch=$(date -d "$proc_lstart" +%s 2>/dev/null)
        fi
        [ -z "$proc_epoch" ] && continue

        # 時間差チェック（±15秒）
        local diff=$(( proc_epoch - desktop_epoch ))
        if [ "$diff" -lt 0 ]; then
            diff=$(( -diff ))
        fi
        if [ "$diff" -le "$time_window" ]; then
            echo "$pid $cpu"
        fi
    done
}

# macOS 通知を送信
# $1: メッセージ本文
# $2: タイトル（省略時: "Claude Process Monitor"）
notify() {
    local message="$1"
    local title="${2:-Claude Process Monitor}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript 2>/dev/null - "$message" "$title" <<'EOF' || true
on run argv
    display notification (item 1 of argv) with title (item 2 of argv)
end run
EOF
    fi
}

# 指定 PID が保護対象かどうか判定
is_protected_pid() {
    local pid="$1"
    local protected
    for protected in "${PROTECTED_PIDS[@]}"; do
        if [ "$pid" = "$protected" ]; then
            return 0
        fi
    done
    return 1
}
