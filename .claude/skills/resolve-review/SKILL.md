---
name: resolve-review
description: PRレビューコメントを取得し対応が必要な項目を確認 (user)
allowed-tools:
  # ~ is not expanded in allowed-tools patterns (claude-code#14956)
  - Bash(bash /Users/rysk/.claude/skills/resolve-review/fetch.sh*)
  - Bash(bash /Users/rysk/.claude/skills/await-ci/check.sh*)
---

# PRレビュー指摘対応

PRのレビューコメントを取得し、未解決の指摘を分類・対応する。

## 入力

`$ARGUMENTS` に PR 番号が渡される（省略時は現在のブランチから自動検出）。

## 手順

### 1. CI ステータスの確認（オプション）

レビュー指摘対応の前に CI 状態を把握しておくと、CI 失敗に起因する指摘を優先対応できる。

`bash /Users/rysk/.claude/skills/await-ci/check.sh $ARGUMENTS` を実行する。

- status が "fail" → 失敗チェック名を記録し、後続の分類で参考にする
- status が "pending" → CI 待機は行わず次のステップに進む
- status が "pass" → そのまま次のステップに進む
- エラー終了 → 無視して次のステップに進む（この手順はオプション）

### 2. ヘルパースクリプトの実行

`bash /Users/rysk/.claude/skills/resolve-review/fetch.sh $ARGUMENTS` を実行する。

- `$ARGUMENTS` が空の場合は引数なしで実行（スクリプト側で自動検出）
- スクリプトが非ゼロ終了した場合は、stderr のエラーメッセージをユーザーに報告して終了

### 3. 出力の解析

スクリプトの stdout は JSON 形式で以下のフィールドを含む。

- `pr_number` - PR番号
- `title` - PRタイトル
- `url` - PR URL
- `review_threads` - レビュースレッドの配列
  - `id` - スレッドID
  - `is_resolved` - 解決済みかどうか
  - `is_outdated` - コード変更により古くなったかどうか
  - `comments` - コメント配列（最初のコメントがレビュー指摘、以降が議論）
    - `body` - コメント本文
    - `author` - コメント投稿者
    - `created_at` - 投稿日時
    - `path` - 対象ファイルパス
    - `line` - 対象行番号
    - `diff_hunk` - 差分コンテキスト

### 4. スレッドの分類

- `is_resolved == true` → 対応済み（表示をスキップ）
- `is_resolved == false` → 要対応

### 5. ユーザーへの報告

以下の形式で報告する。

- PR情報（タイトル、URL）
- 対応済み: N件
- 要対応: N件
- 要対応スレッドの詳細
  - ファイルパスと行番号
  - 指摘内容（最初のコメント）
  - 議論の経緯（返信コメントがある場合）
  - `is_outdated == true` の場合は「コード変更済み」と注記

### 6. 対応アクションの提案

各未解決スレッドについて。

- コード変更が必要な場合は、具体的な修正箇所と修正内容を示す
- 質問に対しては、明確な回答を準備する
- 対応不要と判断した場合は、その理由を説明する

すべてのコメントに対応した後、レビュアーに再確認を依頼することを提案する。
