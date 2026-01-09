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

| キー | 操作 |
|------|------|
| `↑↓` | ワークツリー選択 |
| `Enter` | セッション開始/再開 |
| `N` | 新規ワークツリー作成 |
| `M` | ワークツリーをマージ |
| `D` | ワークツリー削除 |
| `C` | 設定 |
| `Q` | 終了 |
| `0-9` | クイック選択 |
| `/` | 検索 |
| `Ctrl+E` | セッションからメニューに戻る |

## ステータス表示

| アイコン | 状態 |
|----------|------|
| `●` | Busy（処理中） |
| `◐` | Waiting（入力待ち） |
| `○` | Idle（アイドル） |

## ワークフロー

```bash
# 1. ccmanagerを起動
ccmanager

# 2. N キーで新規worktree作成

# 3. Enter でセッション開始

# 4. Ctrl+E でメニューに戻る

# 5. D キーでworktree削除
```

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
