# git-worktree-runner (gtr)

git worktreeの操作を簡単にするCLIツール。複数のAIエージェントが異なるブランチで並行作業する環境を構築できる。

## インストール

### 1. リポジトリのclone

```bash
git clone https://github.com/coderabbitai/git-worktree-runner.git ~/Repositories/external/git-worktree-runner
```

### 2. PATH設定

`.zshrc` に以下を追加（dotfilesリポジトリでは設定済み）

```bash
GTR_PATH="$HOME/Repositories/external/git-worktree-runner"
if [ -d "$GTR_PATH" ]; then
  export PATH="$GTR_PATH/bin:$PATH"
fi
```

## 初期設定

プロジェクトごとに設定が必要。

```bash
# デフォルトエディタの設定
git gtr config set gtr.editor.default zed

# デフォルトAIツールの設定
git gtr config set gtr.ai.default claude
```

対応エディタ: cursor, vscode, zed など
対応AIツール: claude, aider, codex, continue など

## 基本コマンド

```bash
# worktree作成
git gtr new my-feature

# 現在のブランチからworktree作成
git gtr new my-feature --from-current

# エディタで開く
git gtr editor my-feature

# AIツールを起動
git gtr ai my-feature

# worktree削除
git gtr rm my-feature

# worktree一覧
git gtr list

# worktree内でコマンド実行
git gtr run my-feature "npm test"
```

## 更新方法

```bash
cd ~/Repositories/external/git-worktree-runner
git pull
```

## 参考

- リポジトリ: <https://github.com/coderabbitai/git-worktree-runner>
