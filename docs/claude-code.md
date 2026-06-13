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

公開可能な skill は `rysk-tanaka/skills` リポジトリで canonical 管理し、`mise run setup-skills` が `.claude/skills/<name>` に symlink として配置します。
外部 skill（`anthropics/skills` の skill-creator、`mizchi/skills` の empirical-prompt-tuning 等）は実体を dotfiles に持たず gitignore し、同じ `mise run setup-skills` が catalog.json の `source` を見て `gh skill install` で復元します。
環境依存の自作 skill のみ dotfiles 内で実体ディレクトリとして管理します。

スキルの追加・更新時は `.claude/skills/catalog.json` も合わせて更新してください。
シェルスクリプトを含むスキルは `.claude/settings.json` の `permissions.allow` にも実行パターンの追加が必要です（例: `Bash(bash /Users/rysk/.claude/skills/<name>/<script>:*)`）。

### 公開可能なスキル（rysk-tanaka/skills 経由の symlink）

- `/auto-commit` - ステージ済みの変更からConventional Commits形式のコミットメッセージを自動生成してコミット
- `/await-ci` - CIチェックの状態確認・完了待機
- `/cloudwatch-logs` - CloudWatchログの取得・検索（boto3ベースのPythonスクリプト）
- `/codex-review` - Codex CLIによるコードレビュー（フォアグラウンドデフォルト、`--bg` でバックグラウンド実行）
- `/drawio` - draw.io図表をネイティブ.drawioファイルとして生成（PNG/SVG/PDFエクスポート対応）
- `/drawio-aws` - draw.ioでAWSアーキテクチャ図を作成（AWS 4アイコン、カテゴリ別カラー指定付き）
- `/pr` - ブランチの変更を分析してプルリクエストを作成
- `/resolve-review` - PRレビューコメントを取得し未解決の指摘に対応
- `/suggest-branch` - 作業内容を分析して適切なブランチ名（`feature/` or `fix/`）を提案

### 環境依存（dotfiles で実体管理）

- `/claude-process` - プロセスの状況確認・クリーンアップ・監視（サブコマンド: check, clean, monitor）
- `/read-screen` - cmuxペインの出力を読み取る（cmux 前提）
- `/setup-workflows` - rysk-tanaka/workflows の reusable workflow を呼び出すラッパーワークフローを対話的に生成
- `/sync-brew` - Brewfileにアプリを追加（セクション自動判定、auto_updates確認）

### 外部スキル

dotfiles には実体を持たず、`mise run setup-skills` が catalog.json の `source`（`owner/repo`）を見て `gh skill install --dir .claude/skills` で復元します（実体が既に在れば skip）。既定は最新追従で、固定したい場合のみ catalog.json エントリに `"pin": "<tag/commit-sha>"` を足すと `--pin` で固定されます。更新は手動 `gh skill update`（`metadata.github-*` で追従）。

- `skill-creator` - anthropics/skills 由来。新規 skill の作成・既存 skill の改善・eval による性能測定を支援
- `empirical-prompt-tuning` - mizchi/skills 由来。バイアスを排した実行者による実証的プロンプトチューニング（評価→反復改善）

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

### WakaTime

コーディング時間を計測する WakaTime プラグイン。

#### 前提条件

- `mise run setup-wakatime` で `~/.wakatime.cfg` を生成済み（1Password 連携が前提。詳細は [README](../README.md) のセットアップ手順を参照）

#### インストール

```bash
/plugin marketplace add https://github.com/wakatime/claude-code-wakatime.git
/plugin install claude-code-wakatime@wakatime
```

インストール後、`/plugin` を実行してプラグインの状態を確認できる。Zed 用の WakaTime プラグインは Zed の Extensions パネルから「wakatime」を検索してインストールする。

### Webwright

code-as-action 方式のブラウザ自動化プラグイン。ステップごとのツール呼び出しではなく、エージェントが再利用可能な Playwright スクリプトを生成・実行して Web タスクを解く。Playwright MCP（`.mcp.json` 管理、対話的なブラウザ操作向け）とは役割が異なり、反復実行・再現性・スクリプト資産化に向く。ホストエージェント（Claude Code）が直接駆動するため、追加の API キーやコストは不要。

#### インストール

```bash
/plugin marketplace add microsoft/Webwright
/plugin install webwright@webwright
```

この dotfiles では marketplace 登録が `.claude/settings.json` に済んでいるため、設定適用済みの環境では `/plugin install webwright@webwright` だけでよい。

plugin 本体（`src/webwright` の Python コードと SKILL.md）は `~/.claude/plugins/marketplaces/webwright/` にグローバル展開される。リポジトリごとの導入は不要。

#### ランタイム環境のセットアップ（一度きり）

SKILL.md は `playwright` / `httpx` / `pydantic` が「導入済み」であることを前提とし、skill 内での `pip install` を禁じている。そのため Bash ツールが叩く Python（mise グローバルの `python3`）に依存を入れておく必要がある。plugin marketplace 経由のインストールでは自動で入らない点に注意。

```bash
mise exec -- python -m pip install playwright httpx pydantic
mise exec -- python -m playwright install firefox
```

- ブラウザは Chromium ではなく Firefox を使う（一部サイトが Chromium で `ERR_HTTP2_PROTOCOL_ERROR` になるため）。バイナリはグローバルキャッシュ（`~/Library/Caches/ms-playwright`）に入るので一度きりで全リポジトリ共通
- mise はディレクトリごとに Python が切り替わるため、独自に Python を pin したリポジトリでは上記の依存が見えない。そのリポジトリで使う場合のみ同じインストールが必要
- mise グローバル Python に直接入れるため、他の Python ツールと依存が衝突した場合は `mise exec -- python -m pip uninstall playwright httpx pydantic` で戻せる。隔離したい場合は専用 venv を作ってそこに入れる選択肢もある

#### 使い方

```bash
# ワンショットの Web タスクを実行（入力値は固定）
/webwright:run <task>

# パラメータ化した再利用可能な CLI ツールを生成（argparse で引数化）
/webwright:craft <task>
```

実行結果（`plan.md`・スクリーンショット・アクションログ・`final_script.py`）は作業中のリポジトリの作業ディレクトリに `final_runs/run_<id>/` や `outputs/<task_id>/` として書き出される。Firefox のヘッドレスモード（viewport 1280×1800）でローカル実行される。

`plan.md` や `outputs/` は汎用的な名前のためグローバル ignore（`~/.config/git/ignore`）には入れない（他リポジトリの正規ファイルを隠す恐れがあるため）。Webwright を使うリポジトリ側で個別に ignore する。

```bash
printf '%s\n' 'final_runs/' 'outputs/' 'plan.md' >> .git/info/exclude
```

`.git/info/exclude` はローカル限定で共有されないため、チームで使うリポジトリでは代わりに `.gitignore` に追記する。

#### 認証情報の扱い

skill 自体に認証機構は無く、毎回まっさらなセッションで起動する（`There is NO persistent browser state`）。ログインが必要なサイトの自動化では、エージェントが書く Playwright スクリプト側で認証を組む必要がある。安全な順に以下の方針を取る。

1. 手動ログイン + `storage_state`（推奨）。表示あり（`headless=False`）で起動して人間がログインし、`context.storage_state(path=...)` で cookie / localStorage（必要なら IndexedDB）を保存。以降の run は `new_context(storage_state=...)` で認証済み状態から開始する。認証情報がエージェント・チャット・コードのどこにも残らず、SSO / Cognito / MFA でもそのまま通る（Cognito トークンは localStorage 保存なので捕捉される）
2. CDP アタッチ。ログイン済みの実 Chrome/Edge を `--remote-debugging-port` で起動し `connect_over_cdp` で接続。普段使いのプロファイル資産を使え、やはり認証情報を渡さない
3. シークレットからプログラム的ログイン（完全自動が必須な CI 等のみ）。実行時に env や `op read` で取得し、`final_script.py` には埋め込まない

```python
# 1回目: 手動ログイン捕捉（headless=False）
browser = await pw.firefox.launch(headless=False)
ctx = await browser.new_context()
page = await ctx.new_page()
await page.goto("http://localhost:3000/login")
await page.wait_for_url(lambda u: "/login" not in u, timeout=300_000)  # 人間のログイン待ち
await ctx.storage_state(path="outputs/.auth/state.json")

# 2回目以降: 認証済みで検証（headless=True 可）
ctx = await browser.new_context(storage_state="outputs/.auth/state.json")
```

衛生ルール。

- `storage_state` ファイルは bearer トークン相当。コミット・チャット貼り付け禁止。`outputs/.auth/` など ignore 済みディレクトリに置く
- `final_script.py` に認証情報を埋め込まない（ディスク保存される成果物のため）。env / `op read` 経由で渡す
- 専用テストアカウントを使い、個人 / admin アカウントは使わない
- `storage_state` は失効するため、期限切れたら手動ログイン step をやり直す
- ログイン捕捉だけ headed、検証は headless に分けると人手は最初の 1 回で済む

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
