# CloudWatchログ取得

AWS CLIを使用してCloudWatchログを取得・検索します。
Lambda関数のログ解析、エラー調査、アプリケーション監視に利用します。

## 使用方法

使用前にロググループ名を環境変数に設定するか、コマンド実行時に指定します。

```bash
# 環境変数として設定
export LOG_GROUP_NAME="/aws/lambda/your-function-name"

# または、コマンド実行時に直接指定
LOG_GROUP_NAME="/aws/lambda/your-function-name"
```

## 基本コマンド

### 1. ロググループのログを取得

```bash
# 基本的な取得
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME"

# 出力をjqで整形
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --output json | jq '.events[] | {timestamp, message}'
```

### 2. 時間範囲を指定して取得

```bash
# 過去1時間のログを取得（macOS）
START_TIME=$(python3 -c "import time; print(int((time.time() - 3600) * 1000))")
END_TIME=$(python3 -c "import time; print(int(time.time() * 1000))")
aws logs filter-log-events --log-group-name "$LOG_GROUP_NAME" --start-time $START_TIME --end-time $END_TIME

# 特定期間を指定（Unix timestamp in milliseconds）
aws logs filter-log-events --log-group-name "$LOG_GROUP_NAME" --start-time 1704067200000 --end-time 1704153600000
```

### 3. フィルターパターンで検索

```bash
# ERRORログのみ取得
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "ERROR"

# 複数条件（ORマッチ）
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "?ERROR ?WARNING ?CRITICAL"

# 特定の文字列を除外
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '- "health check"'
```

## 高度な使用例

### 4. JSONログのフィールド検索

```bash
# JSON形式のログから特定フィールドを検索
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ $.statusCode = 500 }'

# 複数条件の組み合わせ
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ $.statusCode >= 400 && $.requestId = "*" }'
```

### 5. 特定のログストリームを対象

```bash
# 特定のストリーム名を指定
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-names "2024/01/15/[$LATEST]abc123"

# ストリーム名プレフィックスで絞り込み
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name-prefix "2024/01/15"
```

### 6. ページネーション制御

```bash
# 最大10件のイベントのみ取得
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --max-items 10

# ページサイズを指定（API呼び出しの最適化）
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP_NAME" \
  --page-size 100 \
  --max-items 500
```

### 7. インターリーブオプション（複数ストリームの統合）

```bash
# 複数のログストリームを時系列で統合表示（過去30分）
START_TIME=$(python3 -c "import time; print(int((time.time() - 1800) * 1000))")
aws logs filter-log-events --log-group-name "$LOG_GROUP_NAME" --interleaved --start-time $START_TIME
```

## 便利なワンライナー

```bash
# 最新のエラーログを10件取得して整形
aws logs filter-log-events --log-group-name "$LOG_GROUP_NAME" --filter-pattern ERROR --max-items 10 --output json | jq -r '.events[] | "\(.timestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S")): \(.message)"'

# 最新30件のログを取得（時間指定なし）
aws logs filter-log-events --log-group-name "$LOG_GROUP_NAME" --max-items 30 --output json | jq -r '.events[] | .message'

# 特定のリクエストIDを追跡
REQUEST_ID="abc-123-def-456"
aws logs filter-log-events --log-group-name "$LOG_GROUP_NAME" --filter-pattern "\"$REQUEST_ID\"" --output json | jq '.events[] | .message'
```

## 関数ベースの便利コマンド

`.zshrc`や`.bashrc`に追加して使用できる関数。

```bash
# CloudWatchログを簡単に検索する関数
cwlogs() {
  local group_name="${1:-$LOG_GROUP_NAME}"
  local filter_pattern="$2"
  local max_items="${3:-50}"

  if [ -z "$group_name" ]; then
    echo "Usage: cwlogs <log-group-name> [filter-pattern] [max-items]"
    return 1
  fi

  if [ -n "$filter_pattern" ]; then
    aws logs filter-log-events \
      --log-group-name "$group_name" \
      --filter-pattern "$filter_pattern" \
      --max-items "$max_items" \
      --output json | jq -r '.events[] | "\(.timestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S")): \(.message)"'
  else
    aws logs filter-log-events \
      --log-group-name "$group_name" \
      --max-items "$max_items" \
      --output json | jq -r '.events[] | "\(.timestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S")): \(.message)"'
  fi
}

# 使用例
# cwlogs /aws/lambda/my-function
# cwlogs /aws/lambda/my-function ERROR
# cwlogs /aws/lambda/my-function ERROR 100
```

## パラメータ説明

| パラメータ | 説明 |
|-----------|------|
| `--log-group-name` | 検索対象のロググループ名 |
| `--filter-pattern` | ログイベントをフィルタリングするパターン |
| `--start-time` | 開始時刻（Unix timestamp in milliseconds） |
| `--end-time` | 終了時刻（Unix timestamp in milliseconds） |
| `--log-stream-names` | 特定のログストリーム名（複数指定可） |
| `--log-stream-name-prefix` | ログストリーム名のプレフィックス |
| `--max-items` | 取得する最大イベント数 |
| `--page-size` | 1回のAPI呼び出しで取得するイベント数 |
| `--interleaved` | 複数ストリームを時系列で統合 |
| `--output` | 出力形式（json, text, table） |

## 動作確認

動作確認用のサンプルコマンド。実際の使用時は自分のロググループ名に置き換えてください。

```bash
# テスト用ロググループの例
TEST_LOG_GROUP="/aws/lambda/service_event_broker_authorizer_dev"

# ログが存在するか確認
aws logs describe-log-groups \
  --log-group-name-prefix "${TEST_LOG_GROUP%/*}"

# 最新のログイベントを5件取得
aws logs filter-log-events \
  --log-group-name "$TEST_LOG_GROUP" \
  --max-items 5 \
  --output table

# エラーがないか確認（最新100件）
aws logs filter-log-events --log-group-name "$TEST_LOG_GROUP" --filter-pattern ERROR --max-items 100 --output json | jq '.events | length'
```

## 注意事項

- 時刻はUTCで指定（Unix timestamp in milliseconds）
- **macOSでの時間計算**: `date`コマンドの構文がLinuxと異なるため、Python3を使用した時間計算を推奨
  - 例: `START_TIME=$(python3 -c "import time; print(int((time.time() - 3600) * 1000))")`
- **推奨アプローチ**: 時間範囲指定の代わりに`--max-items`で最新N件を取得する方が簡潔
- フィルターパターンは大文字小文字を区別
- 1回の結果は最大1MBまたは10,000イベント
- ページネーションが必要な場合は`--starting-token`を使用
- ログの変換を使用している場合、元のログのみが返される
- IAM権限`logs:FilterLogEvents`が必要

$ARGUMENTS
