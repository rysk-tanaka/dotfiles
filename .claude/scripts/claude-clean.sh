#!/bin/bash

# Claude Code Process Cleanup
# 不要なClaude Codeプロセスをクリーンアップします。現在のセッション以外の古いプロセスを安全に終了します。

set -euo pipefail

echo "=== Claude Code プロセスクリーンアップ開始 ==="

# エラーハンドリング関数
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# 現在のプロセスPIDを取得（このセッションを保護）
current_pid=$$
current_ppid=$(ps -o ppid= -p $current_pid 2>/dev/null | tr -d ' ')

if [ -z "$current_ppid" ]; then
    error_exit "親プロセスIDの取得に失敗しました"
fi

echo "現在のセッション PID: $current_pid (保護対象)"

# Claude Codeプロセスをより精密に取得
get_claude_processes() {
    # より具体的なパターンでClaude Codeプロセスを特定
    pgrep -f "(claude.*code|claude_code)" 2>/dev/null || true
}

# 全Claude Codeプロセスを取得
claude_pids=$(get_claude_processes)

if [ -z "$claude_pids" ]; then
    echo "Claude Codeプロセスが見つかりません"
    exit 0
fi

# プロセス情報を一度だけ取得（パフォーマンス最適化）
claude_process_info=$(ps -o pid,ppid,pcpu,etime,cmd -p $claude_pids 2>/dev/null | grep -v PID || true)

if [ -z "$claude_process_info" ]; then
    echo "Claude Codeプロセス情報の取得に失敗しました"
    exit 0
fi

echo -e "\n=== プロセス終了前の状況 ==="
echo "$claude_process_info"

# 高CPU使用率プロセス（50%以上）を優先的に終了
echo -e "\n=== 高CPU使用率プロセスの終了 ==="
high_cpu_pids=$(echo "$claude_process_info" | awk '$3 > 50 {print $1}')

for pid in $high_cpu_pids; do
    if [ "$pid" != "$current_pid" ] && [ "$pid" != "$current_ppid" ]; then
        cpu_usage=$(echo "$claude_process_info" | awk -v p="$pid" '$1 == p {print $3}')
        if [ -n "$cpu_usage" ]; then
            echo "高CPU使用率プロセス PID:$pid (${cpu_usage}%) を強制終了中..."
            if kill -9 "$pid" 2>/dev/null; then
                echo "✅ PID:$pid を強制終了しました"
                sleep 1
            else
                echo "⚠️ PID:$pid の終了に失敗しました"
            fi
        fi
    fi
done

# 古いプロセス（24時間以上）を終了
echo -e "\n=== 古いプロセスの終了 ==="
current_epoch=$(date +%s)
twenty_four_hours_ago=$((current_epoch - 86400))

for pid in $claude_pids; do
    if [ "$pid" != "$current_pid" ] && [ "$pid" != "$current_ppid" ]; then
        # プロセスの開始時間を取得（エポック秒）
        start_time=$(ps -o lstart= -p "$pid" 2>/dev/null)
        if [ -n "$start_time" ]; then
            # 開始時間をエポック秒に変換
            start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
            if [ $? -eq 0 ] && [ "$start_epoch" -lt "$twenty_four_hours_ago" ]; then
                echo "24時間以上前のプロセス PID:$pid (開始時間: $start_time) を終了中..."
                
                # 段階的終了処理
                if kill "$pid" 2>/dev/null; then
                    echo "SIGTERM を送信しました"
                    sleep 2
                    
                    # まだ生きているか確認
                    if kill -0 "$pid" 2>/dev/null; then
                        echo "正常終了しないため強制終了中..."
                        if kill -9 "$pid" 2>/dev/null; then
                            echo "✅ PID:$pid を強制終了しました"
                        else
                            echo "⚠️ PID:$pid の強制終了に失敗しました"
                        fi
                    else
                        echo "✅ PID:$pid は正常終了しました"
                    fi
                else
                    echo "⚠️ PID:$pid への SIGTERM 送信に失敗しました"
                fi
            else
                echo "PID:$pid は24時間以内に開始されたプロセスです (開始時間: $start_time)"
            fi
        fi
    fi
done

echo -e "\n=== クリーンアップ後の状況 ==="
remaining_pids=$(get_claude_processes)
if [ -n "$remaining_pids" ]; then
    remaining_info=$(ps -o pid,ppid,pcpu,etime,cmd -p $remaining_pids 2>/dev/null | grep -v PID || true)
    if [ -n "$remaining_info" ]; then
        echo "$remaining_info"
        remaining_count=$(echo "$remaining_pids" | wc -w)
        echo -e "\n残存プロセス数: $remaining_count"
    fi
else
    echo "Claude Codeプロセスは見つかりません"
fi

echo -e "\n✅ クリーンアップ完了"
echo "必要に応じて /claude-check で状況を再確認してください"
