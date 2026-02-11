# Claude Code設定

Claude Codeの設定ファイルは現在、他の設定ファイルとは異なる管理方法となっています。

## 設定ファイルの管理

- グローバル指示: `~/.claude/CLAUDE.md` （シンボリックリンクで管理）
- グローバル設定: `~/.claude.json` （Claude Code内部管理のためシンボリックリンク不可）
- カスタムコマンド: `~/.claude/commands/` （シンボリックリンクで管理）
- カスタムスキル: `~/.claude/skills/` （シンボリックリンクで管理）
- スクリプト: `~/.claude/scripts/` （シンボリックリンクで管理）

## カスタムコマンド

以下のカスタムコマンドが利用可能です。

### 開発用コマンド

- `/permalink` - 指定ファイルのGitHubパーマリンクを生成
- `/uv-init` - uvでPythonプロジェクトを初期化（pyproject.toml設定自動生成、pytest, ruff, mypy付き）
- `/skills` - 利用可能なスキルの一覧を表示

### プロセス管理コマンド

- `/claude-monitor` - プロセス監視と自動クリーンアップ（セッション開始時の日常使用）
- `/claude-check` - プロセス状況の詳細確認（問題調査時）
- `/claude-clean` - 不要プロセスの手動クリーンアップ（問題発生時）

## カスタムスキル

スキルの追加・更新時は `.claude/skills/catalog.json` も合わせて更新してください（`/skills` コマンドで参照されます）。
シェルスクリプトを含むスキルは `.claude/settings.json` の `permissions.allow` にも実行パターンの追加が必要です（例: `Bash(bash /Users/rysk/.claude/skills/<name>/<script>:*)`）。

- `/cloudwatch-logs` - CloudWatchログの取得・検索（boto3ベースのPythonスクリプトで実装）
- `/sync-brew` - Brewfileにアプリを追加（セクション自動判定、auto_updates確認）
- `/auto-commit` - ステージ済みの変更からConventional Commits形式のコミットメッセージを自動生成してコミット
- `/suggest-branch` - 作業内容を分析して適切なブランチ名（`feature/` or `fix/`）を提案
- `/pr` - ブランチの変更を分析してプルリクエストを作成
- `/resolve-review` - PRレビューコメントを取得し未解決の指摘に対応
- `/await-ci` - CIチェックの状態確認・完了待機

## 設定変更方法

設定変更は `claude config` コマンドを使用してください。

## 今後の展望

- `~/.claude.json` はClaude Code内部で管理されるファイルのため、シンボリックリンクでの管理は推奨されません
- 将来的にClaude Code側で設定ファイルの仕様が統一されれば、他の設定ファイル同様にシンボリックリンクでの管理が可能になる予定です
