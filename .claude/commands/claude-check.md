# Claude Code Process Check

Claude Codeのプロセス状況を確認し、異常なプロセスがないかチェックします。

## Command

```bash
echo "=== Claude Code プロセス一覧 ==="
ps aux | grep claude | grep -v grep | sort -k3 -nr

echo -e "\n=== CPU使用率上位3プロセス ==="
ps aux | grep claude | grep -v grep | sort -k3 -nr | head -3 | while read line; do
  pid=$(echo "$line" | awk '{print $2}')
  cpu=$(echo "$line" | awk '{print $3}')
  time=$(echo "$line" | awk '{print $10}')
  echo "PID: $pid | CPU: ${cpu}% | Time: $time"
done

echo -e "\n=== メモリ使用量合計 ==="
total_mem=$(ps aux | grep claude | grep -v grep | \
  awk '{sum += $6} END {printf "%.1f MB\n", sum/1024}')
echo "Total Memory: $total_mem"

echo -e "\n=== プロセス数 ==="
process_count=$(ps aux | grep claude | grep -v grep | wc -l)
echo "Total Processes: $process_count"

if [ "$process_count" -gt 5 ]; then
  echo -e "\n⚠️  警告: Claude Codeプロセスが多数実行中です（$process_count個）"
  echo "不要なプロセスのクリーンアップを検討してください: /claude-clean"
fi

# CPU使用率が50%以上のプロセスをチェック
high_cpu=$(ps aux | grep claude | grep -v grep | awk '$3 > 50 {print $2, $3}')
if [ -n "$high_cpu" ]; then
  echo -e "\n🚨 高CPU使用率プロセス発見:"
  echo "$high_cpu" | while read pid cpu; do
    echo "PID: $pid | CPU: ${cpu}%"
  done
  echo "異常プロセスの強制終了を検討してください"
fi
```
