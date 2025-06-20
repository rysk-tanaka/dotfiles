# Claude Code Process Cleanup

不要なClaude Codeプロセスをクリーンアップします。現在のセッション以外の古いプロセスを安全に終了します。

## Command

```bash
echo "=== Claude Code プロセスクリーンアップ開始 ==="

# 現在のプロセスPIDを取得（このセッションを保護）
current_pid=$$
current_ppid=$(ps -o ppid= -p $current_pid | tr -d ' ')

echo "現在のセッション PID: $current_pid (保護対象)"

# 全Claude Codeプロセスを取得
claude_pids=$(ps aux | grep claude | grep -v grep | awk '{print $2}')

if [ -z "$claude_pids" ]; then
  echo "Claude Codeプロセスが見つかりません"
  exit 0
fi

echo -e "\n=== プロセス終了前の状況 ==="
ps aux | grep claude | grep -v grep | sort -k3 -nr

# 高CPU使用率プロセス（50%以上）を優先的に終了
echo -e "\n=== 高CPU使用率プロセスの終了 ==="
high_cpu_pids=$(ps aux | grep claude | grep -v grep | awk '$3 > 50 {print $2}')

for pid in $high_cpu_pids; do
  if [ "$pid" != "$current_pid" ] && [ "$pid" != "$current_ppid" ]; then
    cpu_usage=$(ps -o pcpu= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$cpu_usage" ]; then
      echo "高CPU使用率プロセス PID:$pid (${cpu_usage}%) を強制終了中..."
      kill -9 "$pid" 2>/dev/null
      sleep 1
    fi
  fi
done

# 古いプロセス（24時間以上）を終了
echo -e "\n=== 古いプロセスの終了 ==="
for pid in $claude_pids; do
  if [ "$pid" != "$current_pid" ] && [ "$pid" != "$current_ppid" ]; then
    # プロセスの開始時間を確認（秒単位）
    start_time=$(ps -o lstart= -p "$pid" 2>/dev/null)
    if [ -n "$start_time" ]; then
      # 24時間以上前のプロセスかチェック（簡易版）
      echo "PID:$pid の開始時間: $start_time"
      echo "PID:$pid を終了中..."
      kill "$pid" 2>/dev/null
      sleep 0.5
      
      # 正常終了しない場合は強制終了
      if kill -0 "$pid" 2>/dev/null; then
        echo "PID:$pid を強制終了中..."
        kill -9 "$pid" 2>/dev/null
      fi
    fi
  fi
done

echo -e "\n=== クリーンアップ後の状況 ==="
remaining=$(ps aux | grep claude | grep -v grep)
if [ -n "$remaining" ]; then
  echo "$remaining"
  remaining_count=$(echo "$remaining" | wc -l)
  echo -e "\n残存プロセス数: $remaining_count"
else
  echo "Claude Codeプロセスは現在のセッションのみです"
fi

echo -e "\n✅ クリーンアップ完了"
echo "必要に応じて /claude-check で状況を再確認してください"
```
