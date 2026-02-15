---
name: codex-review
description: Codex CLIでコードレビューを実行し指摘内容を取得・対応 (user)
allowed-tools:
  # ~ is not expanded in allowed-tools patterns (claude-code#14956)
  - Bash(bash /Users/rysk/.claude/skills/codex-review/review.sh *)
---

# Codex CLI コードレビュー

Codex CLI の `codex review` を実行し、レビュー結果を取得・整理してユーザーに報告する。

## 入力

`$ARGUMENTS` にベースブランチが渡される（省略時は main）。

## 手順

### 1. レビューの実行

`bash /Users/rysk/.claude/skills/codex-review/review.sh $ARGUMENTS` を実行する。

- `$ARGUMENTS` が空の場合は引数なしで実行（デフォルト: main）
- Bash tool の timeout パラメータは 600000（最大値）を指定する
- スクリプトが非ゼロ終了した場合は、エラー内容をユーザーに報告する

### 2. レビュー結果の分類

出力されたレビュー結果を以下のカテゴリに分類する。

- 重大な問題 - バグ、セキュリティリスク、データ損失の可能性
- 改善提案 - パフォーマンス、可読性、保守性の改善
- 軽微な指摘 - スタイル、命名、コメントの改善
- 情報提供 - 質問、確認事項、補足情報

### 3. 構造化レポート

分類した結果を構造化してユーザーに報告する。

- カテゴリごとにグループ化
- 各指摘に対象ファイルと行番号を含める（レビュー結果に記載がある場合）
- 重大な問題がない場合はその旨を明記する

### 4. 修正提案

重大な問題と改善提案について、修正方針を提示する。

- ユーザーの承認を得てから修正を実施する
- 修正は最小限に留める（指摘された箇所のみ）

### 5. 再レビューの提案

修正を実施した場合、再レビューを提案する。

```text
修正が完了しました。再レビューを実行しますか？ → /codex-review
```
