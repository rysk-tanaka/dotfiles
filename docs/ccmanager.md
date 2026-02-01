# ccmanager

AIコーディングアシスタントのセッションを管理するCLIツール。TUIで複数のClaude Codeセッションを一元管理できる。

## 特徴

- セッション状態（Busy/Waiting/Idle）の可視化
- worktree作成時にセッション履歴をコピー可能
- 複数プロジェクトのセッションを一元管理

## インストール

dotfilesリポジトリでは `.config/mise/config.toml` に設定済み。

```bash
mise install
```

## 起動

```bash
ccmanager
```

## 基本操作

| キー       | 操作                         |
| ---------- | ---------------------------- |
| `Up/Down`  | ワークツリー選択             |
| `Enter`    | セッション開始/再開          |
| `N`        | 新規ワークツリー作成         |
| `M`        | ワークツリーをマージ         |
| `D`        | ワークツリー削除             |
| `C`        | 設定                         |
| `Q`        | 終了                         |
| `0-9`      | クイック選択                 |
| `/`        | 検索                         |
| `Ctrl+E`   | セッションからメニューに戻る |

## ステータス表示

| アイコン | 状態               |
| -------- | ------------------ |
| `●`      | Busy（処理中）     |
| `◐`      | Waiting（入力待ち）|
| `○`      | Idle（アイドル）   |

## ワークフロー

### 新規ブランチで作業開始

```bash
# 1. ccmanagerを起動
ccmanager

# 2. N キーで新規worktree作成
#    - Base branch: main を選択
#    - Strategy: "Create new branch from base branch" を選択
#    - ブランチ名を入力

# 3. Enter でセッション開始

# 4. Ctrl+E でメニューに戻る

# 5. D キーでworktree削除
```

### PRブランチをworktreeとして取得

ccmanagerはローカルブランチのみ表示するため、事前にfetchが必要。

```bash
# 1. PRのブランチをfetch
gh pr checkout <PR番号> --detach
git switch -  # 元のブランチに戻る（任意）

# 2. ccmanagerを起動
ccmanager

# 3. N キーで新規worktree作成
#    - Base branch: PRのブランチ名を検索・選択
#    - Strategy: "Use existing base branch" を選択
```

または、ccmanagerを使わずにworktreeを作成してから起動する方法もある。

```bash
# worktreeを直接作成
git fetch origin pull/<PR番号>/head:pr-<PR番号>
git worktree add ../pr-<PR番号> pr-<PR番号>

# ccmanagerで認識される
ccmanager
```

### ブランチ作成戦略の違い

| 戦略                               | 用途                                                   |
| ---------------------------------- | ------------------------------------------------------ |
| Create new branch from base branch | 新機能開発。base branchから新しいブランチを作成        |
| Use existing base branch           | PRレビュー等。既存ブランチをそのままworktreeとして使用 |

## セッション履歴

### 保存場所

セッション履歴はプロジェクトの `.claude/` ではなく、グローバルに保存される。

```text
~/.claude/projects/-Users-<username>-path-to-repo/
~/.claude/projects/-Users-<username>-path-to-repo-<worktree名>/
```

### worktree削除後のセッション履歴

ccmanagerでworktreeを削除しても、`~/.claude/projects/` 内のセッション履歴は削除されない。

```bash
# セッション一覧を確認
ls ~/.claude/projects/

# 特定のセッションを再開（セッションIDがわかれば）
claude --resume <session-id>

# 不要なセッション履歴を削除する場合
rm -rf ~/.claude/projects/-Users-<username>-path-to-repo-<worktree名>
```

### Copy session data

新規worktree作成時に、現在のworktreeのセッション履歴を新しいworktreeにコピーする機能。

| シナリオ                           | Copy session data |
| ---------------------------------- | ----------------- |
| 新機能開発（文脈を引き継ぎたい）   | Yes               |
| PRレビュー（独立した作業）         | No                |
| バグ修正（関連する議論を継続）     | Yes               |
| 全く別の作業                       | No                |

注意点。

- コピーは一方向（元worktree → 新worktree）
- コピー後は独立したセッションになる（同期はしない）
- 逆方向（worktree → main）へ履歴を戻す機能はない

## 設定

設定ファイルの場所。

```text
~/.config/ccmanager/config.json
```

## 対応AIアシスタント

- Claude Code
- Gemini CLI
- Codex CLI
- Cursor Agent
- Copilot CLI
- Cline CLI

## 参考

- リポジトリ: <https://github.com/kbwo/ccmanager>
