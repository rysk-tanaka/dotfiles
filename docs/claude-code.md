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
- `/drawio` - draw.io図表をネイティブ.drawioファイルとして生成（PNG/SVG/PDFエクスポート対応）
- `/drawio-aws` - draw.ioでAWSアーキテクチャ図を作成（AWS 4アイコン、カテゴリ別カラー指定付き）
- `/setup-workflows` - rysk-tanaka/workflows の reusable workflow を呼び出すラッパーワークフローを対話的に生成

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

#### 前提条件

- CodeRabbit CLI のインストール（`brew install --cask coderabbit`、Brewfile管理済み）
- `coderabbit auth login` で認証

#### インストール

```bash
/plugin marketplace update claude-plugins-official
/plugin install coderabbit@claude-plugins-official
```

#### 使い方

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

#### GitHub App（PR 自動レビュー）の注意事項

- bot が作成した PR はデフォルトでレビューがスキップされる（"Review skipped. Bot user detected."）
- `@coderabbitai review` コマンドも bot（`github-actions[bot]` 等）からの投稿は無視される。人間ユーザーが投稿する必要がある
- `.coderabbit.yaml` の公式スキーマ（[schema.v2.json](https://coderabbit.ai/integrations/schema.v2.json)）に bot PR の自動レビューを有効化するフィールドは未提供

### Codex (openai-codex)

OpenAI Codex CLI を Claude Code から呼び出すプラグイン。コードレビューやタスク委譲を提供する。

#### 前提条件

- Codex CLI のインストール（`brew install --cask codex`、Brewfile管理済み）
- `codex login` で認証

#### インストール

```bash
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
```

#### セットアップ確認

```bash
/codex:setup
```

#### 使い方

```bash
# コードレビュー（規模に応じて実行モードを提案）
/codex:review

# フォアグラウンドで即座にレビュー
/codex:review --wait

# バックグラウンドでレビュー
/codex:review --background

# ブランチ全体の差分をレビュー
/codex:review --scope branch

# 特定ブランチとの差分をレビュー
/codex:review --base develop

# 敵対的レビュー（設計判断・トレードオフを問う）
/codex:adversarial-review

# フォーカス指定付き敵対的レビュー
/codex:adversarial-review 認証周りを重点的に

# タスク委譲（調査・修正を Codex に依頼）
/codex:rescue このバグの原因を調査して
```

#### review と adversarial-review の違い

- `/codex:review` -- 実装の品質チェック（バグ、一般的な問題の検出）
- `/codex:adversarial-review` -- 設計判断への挑戦（セキュリティ、データ損失、レースコンディション等の実害リスクに特化）

#### review のスコープオプション

| オプション | 動作 |
| --- | --- |
| `--scope auto`（デフォルト） | working tree が dirty なら作業差分、クリーンならブランチ差分 |
| `--scope working-tree` | staged + unstaged + untracked の全変更 |
| `--scope branch` | デフォルトブランチからの全コミット差分 |
| `--base <ref>` | 指定した ref との差分（scope より優先） |

#### Review Gate

stop 前に Codex レビューを必須にする機能。`/codex:setup --enable-review-gate` で有効化。設定は `$TMPDIR` 配下の `state.json` に保存されるため、OS 再起動で初期化される。

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
