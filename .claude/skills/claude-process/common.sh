#!/bin/bash

# Common functions for Claude Code process management scripts

# Claude Code プロセスを取得（Claude Desktop を除外）
# -x: プロセス名の完全一致（Claude Desktop の "Claude" や "Claude Helper" にはマッチしない）
get_claude_processes() {
    pgrep -x "claude" 2>/dev/null || true
}

# エラーハンドリング関数
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# セッション保護用の PID を取得
# グローバル変数 CURRENT_PID, CURRENT_PPID を設定する
# 失敗時は非ゼロを返す（呼び出し元で処理を決定）
init_session_protection() {
    CURRENT_PID=$$
    CURRENT_PPID=$(ps -o ppid= -p "$CURRENT_PID" 2>/dev/null | tr -d ' ')
    if [ -z "$CURRENT_PPID" ]; then
        return 1
    fi
}

# 指定 PID が保護対象かどうか判定
is_protected_pid() {
    local pid="$1"
    [ "$pid" = "$CURRENT_PID" ] || [ "$pid" = "$CURRENT_PPID" ]
}
