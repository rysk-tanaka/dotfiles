# Claude Code設定

Claude Codeの設定ファイルは現在、他の設定ファイルとは異なる管理方法となっています。

## 設定ファイルの管理

- グローバル指示: `~/.claude/CLAUDE.md` （シンボリックリンクで管理）
- グローバル設定: `~/.claude.json` （Claude Code内部管理のためシンボリックリンク不可）
- カスタムコマンド: `~/.claude/commands/` （シンボリックリンクで管理）
- カスタムスキル: `~/.claude/skills/` （シンボリックリンクで管理）

## カスタムコマンド

以下のカスタムコマンドが利用可能です。

- `/permalink` - 指定ファイルのGitHubパーマリンクを生成
- `/uv-init` - uvでPythonプロジェクトを初期化（pyproject.toml設定自動生成、pytest, ruff, mypy付き）
- `/check-bg` - バックグラウンドタスクの結果を確認

## カスタムスキル

スキルの追加・更新時は `.claude/skills/catalog.json` も合わせて更新してください。
シェルスクリプトを含むスキルは `.claude/settings.json` の `permissions.allow` にも実行パターンの追加が必要です（例: `Bash(bash /Users/rysk/.claude/skills/<name>/<script>:*)`）。

- `/cloudwatch-logs` - CloudWatchログの取得・検索（boto3ベースのPythonスクリプトで実装）
- `/sync-brew` - Brewfileにアプリを追加（セクション自動判定、auto_updates確認）
- `/auto-commit` - ステージ済みの変更からConventional Commits形式のコミットメッセージを自動生成してコミット
- `/suggest-branch` - 作業内容を分析して適切なブランチ名（`feature/` or `fix/`）を提案
- `/pr` - ブランチの変更を分析してプルリクエストを作成
- `/resolve-review` - PRレビューコメントを取得し未解決の指摘に対応
- `/await-ci` - CIチェックの状態確認・完了待機
- `/claude-process` - プロセスの状況確認・クリーンアップ・監視（サブコマンド: check, clean, monitor）
- `/codex-review` - Codex CLIによるコードレビュー（フォアグラウンドデフォルト、`--bg` でバックグラウンド実行）

## Codex CLI との共用スキル

以下のスキルは Codex CLI 用にも移植済み（`.codex/skills/`）。cloudwatch-logs の Python スクリプトは Claude Code 側のものを共有している。

- `auto-commit` - コミットメッセージ自動生成
- `suggest-branch` - ブランチ名提案
- `cloudwatch-logs` - CloudWatchログ取得

`allowed-tools` のフォーマットが異なるため（Claude Code: パターンリスト形式、Codex: カンマ区切り文字列）、SKILL.md はツールごとに個別管理している。

## プラグイン

プラグインはスキル、エージェント、フック、MCPサーバーをパッケージ化して配布・インストールできる仕組み。
マーケットプレース（プラグインカタログ）経由でインストールする。

### マーケットプレース管理

```bash
# マーケットプレースの追加
/plugin marketplace add owner/repo

# マーケットプレースの更新
/plugin marketplace update marketplace-name

# マーケットプレースの一覧
/plugin marketplace list

# マーケットプレースの削除（インストール済みプラグインも削除される）
/plugin marketplace remove marketplace-name
```

公式マーケットプレース `claude-plugins-official` はデフォルトで利用可能。
プラグイン一覧が古い場合は `update` で最新化する。

### プラグインのインストール

```bash
# インストール（user スコープ）
/plugin install plugin-name@marketplace-name

# スコープ指定（user / project / local）
/plugin install plugin-name@marketplace-name --scope project

# アンインストール
/plugin uninstall plugin-name@marketplace-name

# 無効化（アンインストールせず一時停止）
/plugin disable plugin-name@marketplace-name

# 有効化
/plugin enable plugin-name@marketplace-name
```

インストール後は Claude Code の再起動が必要。

### CodeRabbit

AI コードレビュープラグイン。40以上の静的解析ツールとAST解析による指摘を提供する。

前提条件

- CodeRabbit CLI のインストール（`brew install --cask coderabbit`、Brewfile管理済み）
- `coderabbit auth login` で認証

インストール

```bash
/plugin marketplace update claude-plugins-official
/plugin install coderabbit@claude-plugins-official
```

使い方

```bash
# 全変更をレビュー
/coderabbit:review

# コミット済みのみ
/coderabbit:review committed

# 未コミットのみ
/coderabbit:review uncommitted

# 特定ブランチとの差分
/coderabbit:review --base main
```

## Hooks

### Notification

`.claude/settings.json` の `hooks.Notification` で設定。通知イベント発生時にコマンドを実行できる。
`matcher` フィールドで `notification_type` によるフィルタリングが可能（パイプ区切り）。

通知タイプは以下の4種類。

| notification_type | 発火タイミング |
| --- | --- |
| permission_prompt | ツール実行の許可プロンプト表示時（Allow/Deny） |
| idle_prompt | 作業完了後、ユーザー入力待ち状態になった時 |
| auth_success | 認証フロー（OAuth等）が成功した時 |
| elicitation_dialog | AskUserQuestion等のダイアログ表示時 |

現在の設定では `permission_prompt` を除外している（セッション中に頻発し通知過多になるため）。

## 設定変更方法

設定変更は `claude config` コマンドを使用してください。

## 今後の展望

- `~/.claude.json` はClaude Code内部で管理されるファイルのため、シンボリックリンクでの管理は推奨されません
- 将来的にClaude Code側で設定ファイルの仕様が統一されれば、他の設定ファイル同様にシンボリックリンクでの管理が可能になる予定です
