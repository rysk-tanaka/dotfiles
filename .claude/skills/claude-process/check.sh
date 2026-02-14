#!/bin/bash

# Claude Code Process Check
# Claude Codeのプロセス状況を確認し、異常なプロセスがないかチェックします。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "=== Claude Code プロセス一覧 ==="

# Claude Codeプロセスを取得
claude_pids=$(get_claude_processes)

if [ -z "$claude_pids" ]; then
    echo "Claude Code プロセスが見つかりません"
    exit 0
fi

# プロセス情報を一度だけ取得（パフォーマンス最適化）
claude_processes=$(ps -o pid,ppid,pcpu,pmem,vsz,etime,cmd -p $claude_pids 2>/dev/null | grep -v PID || true)

if [ -z "$claude_processes" ]; then
    echo "Claude Code プロセス情報の取得に失敗しました"
    exit 0
fi

# プロセス一覧を表示（CPU使用率順）
echo "$claude_processes" | sort -k3 -nr

echo -e "\n=== CPU使用率上位3プロセス ==="
echo "$claude_processes" | sort -k3 -nr | head -3 | while read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    cpu=$(echo "$line" | awk '{print $3}')
    time=$(echo "$line" | awk '{print $6}')
    echo "PID: $pid | CPU: ${cpu}% | Time: $time"
done

echo -e "\n=== メモリ使用量合計 ==="
total_mem=$(echo "$claude_processes" | awk '{sum += $5} END {printf "%.1f", sum/1024}')
if [ -z "$total_mem" ] || [ "$total_mem" = "" ]; then
    total_mem="0.0"
fi
echo "Total Memory: ${total_mem} MB"

echo -e "\n=== プロセス数 ==="
# より堅牢なプロセス数カウント（空行を除外）
process_count=$(echo "$claude_processes" | grep -c '^[[:space:]]*[0-9]' || echo "0")
echo "Total Processes: $process_count"

if [ "$process_count" -gt 5 ]; then
    echo -e "\n⚠️  警告: Claude Codeプロセスが多数実行中です（$process_count個）"
    echo "不要なプロセスのクリーンアップを検討してください: /claude-process clean"
fi

# CPU使用率が50%以上のプロセスをチェック
high_cpu_processes=$(echo "$claude_processes" | awk '$3 > 50 {print $1, $3}')
if [ -n "$high_cpu_processes" ]; then
    echo -e "\n🚨 高CPU使用率プロセス発見:"
    echo "$high_cpu_processes" | while read -r pid cpu; do
        echo "PID: $pid | CPU: ${cpu}%"
    done
    echo "異常プロセスの強制終了を検討してください"
fi

# 長時間実行されているプロセスをチェック
echo -e "\n=== 実行時間の長いプロセス ==="
echo "$claude_processes" | awk '{print $1, $6}' | while read -r pid etime; do
    echo "PID: $pid | 実行時間: $etime"
done
