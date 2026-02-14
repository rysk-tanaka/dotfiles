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
