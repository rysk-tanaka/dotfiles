#!/bin/bash

# Claude Code Process Monitor
# Claude Codeプロセスを定期的に監視し、異常を検出したら自動でクリーンアップを実行します。
# 日常的な使用で、セッション開始時に実行することを推奨します。

echo "=== Claude Code プロセス監視開始 ==="

# 監視関数
monitor_claude_processes() {
  # 現在のプロセス数
  process_count=$(ps aux | grep claude | grep -v grep | wc -l)

  # 高CPU使用率プロセス
  high_cpu_count=$(ps aux | grep claude | grep -v grep | \
    awk '$3 > 80 {print}' | wc -l)

  # メモリ使用量（MB）
  total_mem=$(ps aux | grep claude | grep -v grep | \
    awk '{sum += $6} END {printf "%.0f", sum/1024}')

  echo "$(date '+%H:%M:%S') | プロセス数: $process_count | 高CPU: $high_cpu_count | \
メモリ: ${total_mem}MB"

  # 異常検出条件
  needs_cleanup=false

  # プロセス数が10個以上
  if [ "$process_count" -gt 10 ]; then
    echo "⚠️  プロセス数異常: $process_count 個"
    needs_cleanup=true
  fi

  # 高CPU使用率プロセスが存在
  if [ "$high_cpu_count" -gt 0 ]; then
    echo "🚨 高CPU使用率プロセス検出: $high_cpu_count 個"
    needs_cleanup=true
  fi

  # メモリ使用量が2GB以上
  if [ "$total_mem" -gt 2048 ]; then
    echo "📊 高メモリ使用量: ${total_mem}MB"
    needs_cleanup=true
  fi

  if [ "$needs_cleanup" = true ]; then
    echo "🔧 自動クリーンアップを実行します..."
    # クリーンアップ実行（claude-clean.mdから主要部分を抽出）
    current_pid=$$
    current_ppid=$(ps -o ppid= -p $current_pid | tr -d ' ')

    # 高CPU使用率プロセスを強制終了
    high_cpu_pids=$(ps aux | grep claude | grep -v grep | awk '$3 > 80 {print $2}')
    for pid in $high_cpu_pids; do
      if [ "$pid" != "$current_pid" ] && [ "$pid" != "$current_ppid" ]; then
        echo "高CPU使用率プロセス PID:$pid を強制終了"
        kill -9 "$pid" 2>/dev/null
      fi
    done

    # 多数のプロセスがある場合、古いものを終了
    if [ "$process_count" -gt 8 ]; then
      old_pids=$(ps aux | grep claude | grep -v grep | \
        awk '{print $2}' | head -n -3)
      for pid in $old_pids; do
        if [ "$pid" != "$current_pid" ] && [ "$pid" != "$current_ppid" ]; then
          echo "古いプロセス PID:$pid を終了"
          kill "$pid" 2>/dev/null
          sleep 0.2
        fi
      done
    fi

    echo "✅ クリーンアップ完了"
  else
    echo "✅ プロセス状態正常"
  fi
}

# オプション解析
WATCH_MODE=false
INTERVAL=300  # デフォルト5分間隔

while [[ $# -gt 0 ]]; do
  case $1 in
    -w|--watch)
      WATCH_MODE=true
      shift
      ;;
    -i|--interval)
      INTERVAL="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [-w|--watch] [-i|--interval SECONDS] [-h|--help]"
      echo "  -w, --watch     継続監視モード（Ctrl+Cで停止）"
      echo "  -i, --interval  監視間隔（秒単位、デフォルト300秒）"
      echo "  -h, --help      このヘルプを表示"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# 初回実行
monitor_claude_processes

# 継続監視モード
if [ "$WATCH_MODE" = true ]; then
  echo -e "\n継続監視モード開始（${INTERVAL}秒間隔）"
  echo "停止するには Ctrl+C を押してください"

  while true; do
    sleep "$INTERVAL"
    echo -e "\n$(date '+%H:%M:%S') | 定期チェック"
    monitor_claude_processes
  done
else
  echo -e "\n✅ 監視完了"
  echo "継続監視が必要な場合: bash ~/.claude/scripts/claude-monitor.sh --watch"
fi
