---
name: claude-process
description: Claude Codeプロセスの状況確認・クリーンアップ・監視 (user)
allowed-tools:
  # ~ is not expanded in allowed-tools patterns (claude-code#14956)
  - Bash(bash /Users/rysk/.claude/skills/claude-process/check.sh *)
  - Bash(bash /Users/rysk/.claude/skills/claude-process/clean.sh *)
  - Bash(bash /Users/rysk/.claude/skills/claude-process/monitor.sh *)
  - BashOutput
---

# Claude Code プロセス管理

Claude Codeのプロセス状況確認、クリーンアップ、監視を行う。

## 入力

`$ARGUMENTS` にサブコマンドが渡される（省略時は check）。

- (なし) / `check` - プロセス状況確認
- `clean` - 不要プロセスのクリーンアップ
- `monitor` - プロセス監視（異常検出時に自動クリーンアップ）

## 手順

### 1. サブコマンドの判定

`$ARGUMENTS` の先頭の単語でサブコマンドを判定する。

- 空、または `check` → check.sh を実行
- `clean` → clean.sh を実行
- `monitor` → monitor.sh を実行

### 2. スクリプトの実行

該当するスクリプトを実行する。

- check: `bash /Users/rysk/.claude/skills/claude-process/check.sh`
- clean: `bash /Users/rysk/.claude/skills/claude-process/clean.sh`
- monitor: `bash /Users/rysk/.claude/skills/claude-process/monitor.sh`

monitor のオプション。

- (なし) — 一回限りの監視チェック
- `--watch` — フォアグラウンドで継続監視（Ctrl+C で停止）
- `--daemon` — バックグラウンドで継続監視（デーモンモード）
- `--stop` — デーモンを停止
- `--status` — デーモンの状態確認（最新ログ10行を表示）
- `--interval N` — 監視間隔を秒で指定（デフォルト 300秒）

セッション内で `--watch` を使う場合は Bash tool の timeout を 600000（最大値）に設定し、
`run_in_background=true` での実行を提案する。
セッション外で使う場合は `--daemon` を推奨する。

### 3. 結果の報告

スクリプトの出力をそのまま報告する。
異常が検出された場合は、推奨アクションを提示する。

- check で高CPU/多数プロセス検出 → clean の実行を提案
- clean 完了後 → check での再確認を提案
- monitor で異常検出 → 自動クリーンアップの結果を報告

## macOS 通知の前提条件

monitor サブコマンドは異常検出時に osascript 経由で macOS 通知を送信する。
通知を受け取るには、システム設定でスクリプトエディタの通知を有効にする必要がある。

1. スクリプトエディタ.app を起動
2. `display notification "test" with title "test"` を実行
3. 表示される許可バナーをクリックして通知を有効化
4. システム設定 > 通知 > スクリプトエディタ で「バナー」を選択

参考: <https://christina04.hatenablog.com/entry/enable-osascript-notification>
