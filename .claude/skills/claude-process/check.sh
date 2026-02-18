#!/bin/bash

# Claude Code Process Check
# Claude Codeのプロセス状況を確認し、異常なプロセスがないかチェックします。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091 source=common.sh  # -x なしでも警告を抑制
source "$SCRIPT_DIR/common.sh"

echo "=== Claude Code プロセス一覧 ==="

# Claude Codeプロセスを取得
claude_pids=$(get_claude_processes)

if [ -z "$claude_pids" ]; then
    echo "Claude Code プロセスが見つかりません"
    # CLI 不在でも Desktop・関連プロセスのチェックは実行する
fi

if [ -n "$claude_pids" ]; then
    # プロセス情報を一度だけ取得（パフォーマンス最適化）
    # rss: 実メモリ使用量（KB）。vsz は仮想メモリで実態と乖離するため使用しない
    # shellcheck disable=SC2086  # 複数PIDをスペース区切りで渡すため意図的
    claude_processes=$(ps -o pid,ppid,pcpu,pmem,rss,etime,cmd -p $claude_pids 2>/dev/null | grep -v PID || true)

    if [ -n "$claude_processes" ]; then
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
        process_count=$(echo "$claude_processes" | grep -c '^[[:space:]]*[0-9]' || true)
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
    else
        echo "Claude Code プロセス情報の取得に失敗しました"
    fi
fi

# === Claude Desktop セクション ===
desktop_pids=$(get_claude_desktop_processes)

if [ -n "$desktop_pids" ]; then
    # shellcheck disable=SC2086  # 複数PIDをスペース区切りで渡すため意図的
    desktop_processes=$(ps -o pid,pcpu,pmem,rss,etime,comm -p $desktop_pids 2>/dev/null | grep -v PID || true)

    if [ -n "$desktop_processes" ]; then
        echo -e "\n=== Claude Desktop プロセス一覧 ==="
        desktop_count=$(echo "$desktop_processes" | grep -c '^[[:space:]]*[0-9]' || true)
        desktop_mem=$(echo "$desktop_processes" | awk '{sum += $4} END {printf "%.1f", sum/1024}')
        echo "プロセス数: $desktop_count | メモリ合計: ${desktop_mem} MB"
        echo "$desktop_processes" | sort -k2 -nr | head -5 | while read -r pid cpu _mem rss etime comm; do
            echo "PID: $pid | CPU: ${cpu}% | メモリ: $(echo "$rss" | awk '{printf "%.0f", $1/1024}')MB | 時間: $etime | $comm"
        done

        # Desktop 側の高CPU チェック
        high_cpu_desktop=$(echo "$desktop_processes" | awk '$2 > 50 {print $1, $2}')
        if [ -n "$high_cpu_desktop" ]; then
            echo -e "\n🚨 Claude Desktop 高CPU使用率プロセス:"
            echo "$high_cpu_desktop" | while read -r pid cpu; do
                echo "PID: $pid | CPU: ${cpu}%"
            done
            echo "→ Claude Desktop アプリの再起動を推奨します"
        fi
    fi
fi

# === 関連プロセス（高CPU）セクション ===
companion_output=$(get_companion_processes)

if [ -n "$companion_output" ]; then
    echo -e "\n🚨 === 関連プロセス（高CPU） ==="
    echo "Claude Desktop と同時に起動し高CPU を消費しているプロセス:"
    echo "$companion_output" | while read -r pid cpu; do
        comm=$(ps -o comm= -p "$pid" 2>/dev/null || echo "unknown")
        echo "PID: $pid | CPU: ${cpu}% | プロセス: $comm"
    done
    echo "→ Claude Desktop アプリの再起動を推奨します"
fi
