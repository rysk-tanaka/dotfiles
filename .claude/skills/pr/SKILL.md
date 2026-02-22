---
name: pr
description: ブランチの変更を分析してプルリクエストを作成 (user)
allowed-tools:
  # ~ is not expanded in allowed-tools patterns (claude-code#14956)
  - Bash(bash /Users/rysk/.claude/skills/pr/collect.sh*)
---

# プルリクエスト作成

ブランチの変更を分析し、PRテンプレートに従ったプルリクエストを作成する。

## 入力

`$ARGUMENTS` にベースブランチ名が渡される（省略時は `main`）。

## 手順

### 1. ヘルパースクリプトの実行

`bash /Users/rysk/.claude/skills/pr/collect.sh <base-branch>` を実行する。

- ベースブランチは `$ARGUMENTS` が指定されていればそれを使用、なければ `main` を渡す
- スクリプトが非ゼロ終了した場合は、stderr のエラーメッセージをユーザーに報告して終了

### 2. 出力の解析

スクリプトの stdout は JSON 形式で以下のフィールドを含む。

- `current_branch` - 現在のブランチ名
- `base_branch` - ベースブランチ名
- `stat` - 変更ファイルの統計（git diff --stat）
- `log` - コミット一覧（git log --oneline）
- `diff` - 詳細な差分（lockファイル除外済み）
- `template` - PRテンプレートの内容（見つからない場合は空文字列）

diff が非常に大きい場合は、stat を中心に分析する。

### 3. PR内容の生成

#### タイトル

- シンプルな英文
- 先頭は大文字
- 末尾にピリオドを付けない
- ブランチ全体で何を達成したかを簡潔に表現

#### 本文

- template が空でなければ、テンプレートの形式に従って日本語で記述
- template が空の場合は、デフォルト構成（変更の概要、主な変更点、変更の背景）で記述
- 文末はですます調
- 句点（。）で改行する
- 1行は120文字以内に収める（長い文は適切な位置で改行する）
- レビュアーが読みやすいよう、簡潔で要点のみを記載
- 冗長な説明や詳細すぎる技術的説明は避ける
- テンプレートの各項目を埋めるために必要な最小限の情報のみを記載
- 個別のコミット内容ではなく、ブランチ全体で何を変更したかに焦点を当てる
- テンプレートのHTMLコメント（`<!-- -->`）は出力に含めない
- 該当する内容がないセクションは省略する（「なし」と記載しない）

#### 禁止事項

- PR本文に `🤖 Generated with [Claude Code](https://claude.com/claude-code)` を含めない
- PR本文に `Co-Authored-By: Claude <noreply@anthropic.com>` を含めない

### 4. ユーザー確認

生成したPRタイトルと本文を以下の形式でユーザーに提示する。

```text
Title: <タイトル>
Base: <ベースブランチ> ← <現在のブランチ>

<PR本文>
```

ユーザーに「この内容でPRを作成しますか？」と確認する。修正が要望された場合は、フィードバックを反映して再生成する。

### 5. PR作成

ユーザーの承認を得た後、`gh pr create` コマンドを実行する。

```bash
gh pr create --base <base-branch> --title "<タイトル>" --body "<本文>"
```

### 6. 結果の報告

作成されたPRのURLを表示する。

### 7. 次のアクションのサジェスト

PR作成後、PRのURLからPR番号を抽出し、AskUserQuestion ツールで次のアクションを提示する。

- header: `次のアクション`
- question: `PR #<PR番号> を作成しました。次に行うアクションを選択してください。`
- multiSelect: false
- 選択肢
  - `/await-ci <PR番号> --watch` - CI の完了を待機
  - `/resolve-review <PR番号>` - レビュー指摘を確認・対応
  - `/review <PR番号>` - コードレビューを実行
  - `/pr-review-toolkit:review-pr` - PR の包括的レビューを実行
  - `何もしない` - 終了

ユーザーがスキルを選択した場合は、対応する Skill ツールまたは SlashCommand ツールで実行する。
