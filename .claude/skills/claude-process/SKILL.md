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

monitor の場合、ユーザーが継続監視を希望すれば `--watch` フラグ付きで再実行する。
`--watch` 実行時は Bash tool の timeout を 600000（最大値）に設定し、
`run_in_background=true` での実行を提案する。

### 3. 結果の報告

スクリプトの出力をそのまま報告する。
異常が検出された場合は、推奨アクションを提示する。

- check で高CPU/多数プロセス検出 → clean の実行を提案
- clean 完了後 → check での再確認を提案
- monitor で異常検出 → 自動クリーンアップの結果を報告
