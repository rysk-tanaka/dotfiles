---
name: resolve-review
description: PRレビューコメントを取得し対応が必要な項目を確認 (user)
allowed-tools:
  # ~ is not expanded in allowed-tools patterns (claude-code#14956)
  - Bash(bash /Users/rysk/.claude/skills/resolve-review/fetch.sh*)
  - Bash(bash /Users/rysk/.claude/skills/await-ci/check.sh*)
  - BashOutput
---

# PRレビュー指摘対応

PRのレビューコメントを取得し、未解決の指摘を分類・対応する。

## 入力

`$ARGUMENTS` に PR 番号が渡される（省略時は現在のブランチから自動検出）。

## 手順

このスキルは「起動フェーズ」と「結果処理フェーズ」の2段階で動作する。
起動フェーズでバックグラウンド実行を開始し、すぐにユーザーに制御を返す。

### 起動フェーズ

#### 1. CI ステータス確認の開始

`bash /Users/rysk/.claude/skills/await-ci/check.sh $ARGUMENTS --watch` を Bash tool の `run_in_background` パラメータを `true` にして実行する。

- `$ARGUMENTS` が空の場合は引数なしで実行（スクリプト側で自動検出）

#### 2. ユーザーへの報告

以下を報告してスキルの実行を終了する。

- バックグラウンドで CI 待機を開始したこと
- 他のコマンドを実行可能であること
- 完了したら自動的に結果を処理すること（手動確認は `/check-bg`）

### 結果処理フェーズ

以下のいずれかの条件で結果処理フェーズを開始する。

1. ユーザーが結果確認を依頼した場合
2. メッセージに該当バックグラウンドタスクの system-reminder が含まれる場合

条件2の場合はまず BashOutput でステータスを確認し、まだ実行中であればユーザーのメッセージを優先して処理する（結果処理は行わない）。

#### 3. CI ステータスの取得

BashOutput ツールで check.sh の出力を確認する。

- まだ実行中の場合はステータスを報告し、再度確認を依頼するよう案内する
- 完了した場合は CI ステータスを記録する
  - status が "fail" → 失敗チェック名を記録し、後続の分類で参考にする
  - status が "pass" → そのまま次のステップに進む
  - タイムアウト（exit 2）→ その時点の状態を記録し、次のステップに進む
  - エラー終了 → 無視して次のステップに進む（この手順はオプション）

#### 4. ヘルパースクリプトの実行

`bash /Users/rysk/.claude/skills/resolve-review/fetch.sh $ARGUMENTS` を実行する。

- `$ARGUMENTS` が空の場合は引数なしで実行（スクリプト側で自動検出）
- スクリプトが非ゼロ終了した場合は、stderr のエラーメッセージをユーザーに報告して終了

#### 5. 出力の解析

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
- `comments` - 一般コメントの配列（minimized 除外済み）
  - `id` - コメントID
  - `body` - コメント本文
  - `author` - 投稿者
  - `created_at` - 投稿日時
  - `url` - コメントURL

#### 6. コメントの分類

レビュースレッド。

- `is_resolved == true` → 対応済み（表示をスキップ）
- `is_resolved == false` → 要対応

一般コメント。内容から要対応かどうかを判断する。

- レビュー指摘（改善点、問題の指摘）→ 要対応
- サマリー・情報提供のみ → 対応不要

#### 7. ユーザーへの報告

以下の形式で報告する。

- PR情報（タイトル、URL）
- 対応済み: N件
- 要対応: N件
- 要対応スレッドの詳細
  - ファイルパスと行番号
  - 指摘内容（最初のコメント）
  - 議論の経緯（返信コメントがある場合）
  - `is_outdated == true` の場合は「コード変更済み」と注記
- 要対応の一般コメントの詳細
  - 投稿者とコメントURL
  - 指摘内容

#### 8. 対応アクションの提案

各未解決スレッドについて。

- コード変更が必要な場合は、具体的な修正箇所と修正内容を示す
- 質問に対しては、明確な回答を準備する
- 対応不要と判断した場合は、その理由を説明する

すべてのコメントに対応した後、レビュアーに再確認を依頼することを提案する。
