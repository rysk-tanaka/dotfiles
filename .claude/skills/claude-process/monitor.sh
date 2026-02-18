#!/bin/bash

# Claude Code Process Monitor
# Claude Codeプロセスを定期的に監視し、異常を検出したら自動でクリーンアップを実行します。
# 日常的な使用で、セッション開始時に実行することを推奨します。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091 source=common.sh  # -x なしでも警告を抑制
source "$SCRIPT_DIR/common.sh"

echo "=== Claude Code プロセス監視開始 ==="

# 監視関数
monitor_claude_processes() {
    # Claude Codeプロセスを取得
    claude_pids=$(get_claude_processes)

    if [ -z "$claude_pids" ]; then
        echo "$(date '+%H:%M:%S') | プロセス数: 0 | 高CPU: 0 | メモリ: 0MB"
        echo "✅ Claude Codeプロセスが見つかりません"
        return 0
    fi

    # プロセス情報を一度だけ取得（パフォーマンス最適化）
    # rss: 実メモリ使用量（KB）。vsz は仮想メモリで実態と乖離するため使用しない
    # shellcheck disable=SC2086  # 複数PIDをスペース区切りで渡すため意図的
    claude_processes=$(ps -o pid,ppid,pcpu,pmem,rss,cmd -p $claude_pids 2>/dev/null | grep -v PID || true)

    if [ -z "$claude_processes" ]; then
        echo "$(date '+%H:%M:%S') | プロセス数: 0 | 高CPU: 0 | メモリ: 0MB"
        echo "✅ Claude Codeプロセス情報の取得に失敗"
        return 0
    fi

    # 統計計算（より堅牢なカウント手法）
    process_count=$(echo "$claude_processes" | grep -c '^[[:space:]]*[0-9]' || true)
    high_cpu_count=$(echo "$claude_processes" | awk '$3 > 80' | grep -c '^[[:space:]]*[0-9]' || true)
    total_mem=$(echo "$claude_processes" | awk '{sum += $5} END {printf "%.0f", sum/1024}')

    # メモリが計算できない場合の対処
    if [ -z "$total_mem" ] || [ "$total_mem" = "" ]; then
        total_mem=0
    fi

    echo "$(date '+%H:%M:%S') | プロセス数: $process_count | 高CPU: $high_cpu_count | メモリ: ${total_mem}MB"

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

    # Claude Desktop 関連プロセスの高CPU チェック
    companion_output=$(get_companion_processes)
    if [ -n "$companion_output" ]; then
        echo "🚨 Claude Desktop 関連の高CPUプロセス検出:"
        echo "$companion_output" | while read -r pid cpu; do
            comm=$(ps -o comm= -p "$pid" 2>/dev/null || echo "unknown")
            echo "  PID: $pid | CPU: ${cpu}% | プロセス: $comm"
        done
        echo "→ Claude Desktop アプリの再起動を推奨します"
        needs_cleanup=true
    fi

    if [ "$needs_cleanup" = true ]; then
        # 異常検出を通知
        local alert_parts=()
        [ "$high_cpu_count" -gt 0 ] && alert_parts+=("高CPU: ${high_cpu_count}個")
        [ "$process_count" -gt 10 ] && alert_parts+=("プロセス数: ${process_count}個")
        [ "$total_mem" -gt 2048 ] && alert_parts+=("メモリ: ${total_mem}MB")
        [ -n "$companion_output" ] && alert_parts+=("関連プロセス高CPU")
        local alert_msg
        alert_msg=$(IFS=', '; echo "${alert_parts[*]}")
        notify "異常検出: ${alert_msg}。自動クリーンアップを実行します" "⚠️ Claude Process Monitor"

        echo "🔧 自動クリーンアップを実行します..."

        # 現在のプロセス保護
        if ! init_session_protection; then
            echo "⚠️ 親プロセスIDの取得に失敗、クリーンアップをスキップします"
            return 1
        fi

        # 高CPU使用率プロセスを強制終了
        # 自動監視のため段階的終了ではなく即座に SIGKILL を使用
        high_cpu_pids=$(echo "$claude_processes" | awk '$3 > 80 {print $1}')
        for pid in $high_cpu_pids; do
            if ! is_protected_pid "$pid"; then
                echo "高CPU使用率プロセス PID:$pid を強制終了"
                if kill -9 "$pid" 2>/dev/null; then
                    echo "✅ PID:$pid を強制終了しました"
                else
                    echo "⚠️ PID:$pid の終了に失敗しました"
                fi
            fi
        done

        # 多数のプロセスがある場合、古いものを終了
        if [ "$process_count" -gt 8 ]; then
            # プロセス数をチェックしてからhead -n の値を計算
            terminate_count=$((process_count - 3))
            # 境界条件の適切な処理
            if [ "$terminate_count" -gt 0 ] && [ "$terminate_count" -le "$process_count" ]; then
                old_pids=$(echo "$claude_pids" | head -n "$terminate_count")
                if [ -n "$old_pids" ]; then
                    for pid in $old_pids; do
                        if ! is_protected_pid "$pid"; then
                            echo "古いプロセス PID:$pid を終了"
                            if kill "$pid" 2>/dev/null; then
                                sleep 0.2
                                # 正常終了しない場合は強制終了
                                if kill -0 "$pid" 2>/dev/null; then
                                    kill -9 "$pid" 2>/dev/null
                                fi
                            fi
                        fi
                    done
                fi
            else
                echo "⚠️ 終了対象プロセス数が無効です (terminate_count: $terminate_count, process_count: $process_count)"
            fi
        fi

        notify "クリーンアップ完了" "✅ Claude Process Monitor"
        echo "✅ クリーンアップ完了"
    else
        echo "✅ プロセス状態正常"
    fi
}

# デーモン管理用パス
PIDFILE="$HOME/.cache/claude-process-monitor.pid"
LOGFILE="$HOME/.cache/claude-process-monitor.log"

# デーモン停止
stop_daemon() {
    if [ ! -f "$PIDFILE" ]; then
        echo "デーモンは起動していません"
        return 0
    fi
    local pid
    pid=$(cat "$PIDFILE")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PIDFILE"
        echo "✅ デーモンを停止しました (PID: $pid)"
    else
        rm -f "$PIDFILE"
        echo "PIDファイルが残っていましたが、プロセスは既に終了しています"
    fi
}

# デーモンステータス
daemon_status() {
    if [ ! -f "$PIDFILE" ]; then
        echo "デーモンは起動していません"
        return 1
    fi
    local pid
    pid=$(cat "$PIDFILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "✅ デーモン稼働中 (PID: $pid)"
        echo "ログ: $LOGFILE"
        if [ -f "$LOGFILE" ]; then
            echo -e "\n--- 最新ログ (10行) ---"
            tail -10 "$LOGFILE"
        fi
        return 0
    else
        rm -f "$PIDFILE"
        echo "PIDファイルが残っていましたが、プロセスは既に終了しています"
        return 1
    fi
}

# オプション解析
WATCH_MODE=false
DAEMON_MODE=false
DAEMON_ACTION=""
INTERVAL=300  # デフォルト5分間隔

while [[ $# -gt 0 ]]; do
  case $1 in
    -w|--watch)
      WATCH_MODE=true
      shift
      ;;
    -d|--daemon)
      DAEMON_MODE=true
      shift
      ;;
    --stop)
      DAEMON_ACTION="stop"
      shift
      ;;
    --status)
      DAEMON_ACTION="status"
      shift
      ;;
    -i|--interval)
      if [ -z "${2:-}" ]; then
        error_exit "--interval オプションには値が必要です"
      fi
      # 数値検証
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        error_exit "--interval の値は正の整数である必要があります: $2"
      fi
      # 正の値チェック
      if [ "$2" -eq 0 ]; then
        error_exit "--interval の値は0より大きい必要があります: $2"
      fi
      INTERVAL="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "  -w, --watch     継続監視モード（フォアグラウンド、Ctrl+Cで停止）"
      echo "  -d, --daemon    バックグラウンドで継続監視（デーモンモード）"
      echo "  --stop          デーモンを停止"
      echo "  --status        デーモンの状態を確認"
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

# デーモン管理アクション
if [ -n "$DAEMON_ACTION" ]; then
    case "$DAEMON_ACTION" in
        stop)   stop_daemon ;;
        status) daemon_status ;;
    esac
    exit $?
fi

# デーモンモード: バックグラウンドで --watch として再起動
if [ "$DAEMON_MODE" = true ]; then
    if [ -f "$PIDFILE" ]; then
        existing_pid=$(cat "$PIDFILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo "⚠️  デーモンは既に起動しています (PID: $existing_pid)"
            echo "停止するには: bash $0 --stop"
            exit 1
        fi
        rm -f "$PIDFILE"
    fi

    mkdir -p "$(dirname "$LOGFILE")"
    nohup bash "$0" --watch --interval "$INTERVAL" >> "$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    echo "✅ デーモンを起動しました (PID: $!)"
    echo "ログ: $LOGFILE"
    echo "停止: bash $0 --stop | 状態: bash $0 --status"
    exit 0
fi

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
  echo "継続監視: bash $SCRIPT_DIR/monitor.sh --watch"
  echo "バックグラウンド監視: bash $SCRIPT_DIR/monitor.sh --daemon"
fi
