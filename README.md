# dotfiles

MacOS用の初期セットアップを行います。

## ディレクトリ構造

```text
.
├── .zshrc                            # Zshメイン設定
├── .zprofile                         # Zsh環境変数など
├── .vimrc                            # Vim設定
├── .gitconfig                        # Git設定
├── .mcp.json                         # MCPサーバー設定（プロジェクトスコープ）
├── .claude/                          # Claude Code設定
│   ├── CLAUDE.md                     # グローバル指示
│   ├── settings.json                 # グローバル設定
│   ├── commands/                     # カスタムコマンド
│   │   ├── pr.md                     # PRコマンド
│   │   ├── permalink.md              # パーマリンクコマンド
│   │   ├── cloudwatch-logs.md        # CloudWatchログ取得
│   │   ├── claude-check.md           # プロセス状況確認
│   │   ├── claude-monitor.md         # プロセス監視
│   │   └── claude-clean.md           # プロセスクリーンアップ
│   └── scripts/                      # スクリプトファイル
│       ├── claude-check.sh           # プロセス状況確認スクリプト
│       ├── claude-monitor.sh         # プロセス監視スクリプト
│       └── claude-clean.sh           # プロセスクリーンアップスクリプト
├── .config/                          # 各種アプリケーション設定
│   ├── zed/                          # Zedエディタ
│   │   ├── keymap.json               # キーマップ設定
│   │   └── settings.json             # 一般設定
│   ├── ghostty/                      # Ghosttyターミナル
│   │   └── config                    # Ghostty設定
│   ├── starship.toml                 # Starshipプロンプト設定
│   ├── git/                          # Git補助設定
│   │   └── ignore                    # グローバル除外設定
│   └── mise/                         # ツールバージョン管理
│       ├── config.toml               # miseの設定
│       └── shell-functions.sh        # カスタムシェル関数
├── .github/                          # GitHub関連
│   └── workflows/                    # GitHub Actions
│       ├── claude-code-review.yml    # PRの自動レビュー
│       ├── claude.yml                # @claudeメンション応答
│       └── pull_request_template.md  # PRテンプレート
├── .clinerules/                      # コーディング規約
│   ├── 01-coding-standards.md        # コーディング標準
│   └── 02-documentation.md           # ドキュメント規約
├── .pre-commit-config.yaml           # pre-commitフック設定
├── .markdownlint-cli2.jsonc          # markdownlint設定
└── docs/                             # ドキュメント
    ├── claude-code.md                # Claude Code設定詳細
    └── mcp.md                        # MCP設定詳細
```

## セットアップ

### 前提条件

- macOS
- [mise](https://mise.jdx.dev/)（ツールバージョン管理）がインストールされていること

### 手順

1. リポジトリをクローン

    ```bash
    git clone https://github.com/rysk-tanaka/dotfiles.git ~/Repositories/rysk/dotfiles
    cd ~/Repositories/rysk/dotfiles
    ```

2. シンボリックリンクの作成

    設定ファイルを適切な場所にシンボリックリンクします：

    ディレクトリの作成

    ```bash
    mkdir -p ~/.claude
    mkdir -p ~/.config/ghostty
    mkdir -p ~/.config/git
    mkdir -p ~/.config/zed
    ```

    設定ファイルのリンク

    ```bash
    ln -sf ~/Repositories/rysk/dotfiles/.claude/settings.json ~/.claude/settings.json
    ln -sf ~/Repositories/rysk/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md
    ln -sf ~/Repositories/rysk/dotfiles/.claude/commands ~/.claude/commands
    ln -sf ~/Repositories/rysk/dotfiles/.config/ghostty/config ~/.config/ghostty/config
    ln -sf ~/Repositories/rysk/dotfiles/.config/git/ignore ~/.config/git/ignore
    ln -sf ~/Repositories/rysk/dotfiles/.config/mise ~/.config/mise
    ln -sf ~/Repositories/rysk/dotfiles/.config/zed/keymap.json ~/.config/zed/keymap.json
    ln -sf ~/Repositories/rysk/dotfiles/.config/zed/settings.json ~/.config/zed/settings.json
    ln -sf ~/Repositories/rysk/dotfiles/.config/starship.toml ~/.config/starship.toml
    ln -sf ~/Repositories/rysk/dotfiles/.gitconfig ~/.gitconfig
    ln -sf ~/Repositories/rysk/dotfiles/.vimrc ~/.vimrc
    ln -sf ~/Repositories/rysk/dotfiles/.zshrc ~/.zshrc
    ln -sf ~/Repositories/rysk/dotfiles/.zprofile ~/.zprofile
    ```

3. 必要なツールのインストール

    mise を使って必要なツールをインストールします：

    ```bash
    mise install
    ```

    これにより、config.toml に定義されている以下のツールがインストールされます：

    - 1password-cli, awscli, aws-vault, delta, eza, go, jq, node, rust
    - 各種ユーティリティのnpmパッケージ
    - Python 3.12、ripgrep、Starship、Terraformなど
    - Human-In-the-Loop Discord MCPサーバー（Rustバイナリ）

### プロジェクト用セットアップ

各プロジェクトリポジトリ内で以下のコマンドを実行すると、コーディング規約とGitHub設定をリンクします：

```bash
mise run setup-links
```

これは以下のシンボリックリンクを作成します：

- .github/workflows/pull_request_template.md
- .clinerules/
- .pre-commit-config.yaml
- .markdownlint-cli2.jsonc
- .mcp.json

## 開発コマンド

miseで定義されているコマンドを利用できます：

### コード整形

Pythonコードのリントとフォーマットを実行します：

```bash
mise run lint
```

このコマンドは以下の処理を順番に実行します：

1. `ruff format` - Pythonコードを自動フォーマット
2. `ruff check` - コードスタイルとエラーチェック
3. `mypy .` - 静的型チェック

## カスタムシェル関数

`.config/mise/shell-functions.sh`に定義されたシェル関数が自動的に読み込まれます。

### mdlint

markdownlint-cli2のラッパーコマンド。どのサブディレクトリから実行しても、gitルートの設定ファイルが自動的に適用されます。

```bash
# サブディレクトリから実行可能
cd path/to/deep/subdirectory
mdlint README.md --fix

# カレントディレクトリ以下すべてをチェック
mdlint .
```

**動作**:

1. gitルートを検出
2. 実行ファイルのパスをgitルートからの相対パスに変換
3. gitルートに移動して markdownlint-cli2 を実行
4. gitルートの `.markdownlint-cli2.jsonc` が自動適用される

## Python環境の管理

このプロジェクトでは以下のツールでPython環境を管理しています

- mise: グローバルなPython環境（Python 3.12.8）
- uv: プロジェクト固有の仮想環境

### 使い分け

- システム全体で使用するツール → miseでインストール
- プロジェクト固有の依存関係 → uvで仮想環境を作成

```bash
# プロジェクトで仮想環境を作成
uv venv
source .venv/bin/activate
```

## 関連ドキュメント

- [Claude Code設定](./docs/claude-code.md) - Claude Code固有の設定とカスタムコマンド
- [MCP設定](./docs/mcp.md) - MCPサーバーの設定
