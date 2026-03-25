---
name: setup-workflows
description: rysk-tanaka/workflows の reusable workflow を呼び出すラッパーワークフローを対話的に生成
allowed-tools:
  - Bash(mkdir -p *)
  - Bash(ls *)
  - Bash(test *)
  - Read
  - Edit
  - Write
  - Glob
---

# ワークフロー設置スキル

`rysk-tanaka/workflows` の reusable workflow を呼び出すラッパーワークフローを対話的に生成する。

## ステップ1: プロジェクト検出

プロジェクトルートのファイルを確認し、プロジェクトタイプとパッケージマネージャーを自動検出する。

- `package.json` が存在 → Node.js プロジェクト
  - `pnpm-lock.yaml` があれば `pnpm`
  - `yarn.lock` があれば `yarn`
  - それ以外は `npm`
- `pyproject.toml` が存在 → Python プロジェクト
  - `uv.lock` があれば `uv`
  - それ以外は `pip`
- `Cargo.toml` が存在 → Rust プロジェクト
- いずれもなければユーザーに手動で確認する

検出結果をユーザーに表示して確認を取る。

## ステップ2: ワークフロー選択

AskUserQuestion で導入するワークフローを選択してもらう。番号をカンマ区切りで入力（例: `1,2,3`）。Node.js プロジェクトの場合は 6 も選択可能。

```text
導入するワークフローを選択してください（番号をカンマ区切り、例: 1,2,3）:

1. リリース自動化 (auto-release.yml)
   - main への push で package.json/pyproject.toml/Cargo.toml のバージョン変更を検知し、GitHub Release を自動作成
2. Claude Code (claude.yml)
   - Issue/PR で @claude メンションに応答
3. Claude Code Review (claude-code-review.yml)
   - claude-review ラベル付き PR を自動レビュー
4. Issue Scan (issue-scan.yml)
   - 日次 cron で open Issue をトリアージし難易度ラベルを付与
5. Issue Implement (issue-implement.yml)
   - claude-implement ラベル付き Issue を Claude が自動実装
6. Dependabot Scan (dependabot-scan.yml) ※ Node.js プロジェクトのみ
   - 手動実行で脆弱性を検出し Issue を起票
```

## ステップ3: 追加情報の質問

選択されたワークフローに応じて追加情報を収集する。

### リリース自動化が選択された場合

AskUserQuestion で publish 対象を質問する。

```text
リリース時の publish 対象を選択してください（番号をカンマ区切り、不要なら「なし」）:

1. npm レジストリ（vars.PUBLISH_NPM + NPM_TOKEN が必要）
2. Docker (GHCR)（vars.PUBLISH_DOCKER が必要）
3. GitHub Action メジャータグ（vars.PUBLISH_ACTION が必要）
```

### Issue Implement が選択された場合

AskUserQuestion でテスト・lint・format コマンドを質問する。プロジェクトタイプに応じたデフォルト値を提示する。

Node.js (pnpm) の場合は下記の通り。

```text
Issue Implement で使用するコマンドを確認します（Enter でデフォルトを採用、変更があれば入力）:

テスト: pnpm test
lint: pnpm lint
format: pnpm format

上記でよければ「OK」、変更があればコマンドを記載してください。
例: テスト: pnpm run vitest / lint: pnpm run eslint / format: なし
```

Node.js (npm) の場合はデフォルトを `npm test` / `npm run lint` / `npm run format` に変更。
Node.js (yarn) の場合は `yarn test` / `yarn lint` / `yarn format` に変更。
Python (uv) の場合は `uv run pytest` / `uv run ruff check .` / `uv run ruff format .` に変更。
Python (pip) の場合は `pytest` / `ruff check .` / `ruff format .` に変更。
Rust の場合は `cargo test` / `cargo clippy` / `cargo fmt` に変更。

## ステップ4: ファイル生成

`.github/workflows/` ディレクトリが存在しなければ `mkdir -p` で作成する。

既に同名のファイルが存在する場合は、ユーザーに上書きするか確認する。

以下のテンプレートに基づいてファイルを生成する。

Note: Claude 系テンプレートの `id-token: write` は、reusable workflow 内で `anthropics/claude-code-action@v1` が OIDC 認証を使用するために必要。`dependabot-scan.yml` は Claude を使用しないため不要。

### claude.yml

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  claude:
    if: |
      (github.event_name == 'issue_comment' && (contains(github.event.comment.body, '@claude ') || github.event.comment.body == '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && (contains(github.event.comment.body, '@claude ') || github.event.comment.body == '@claude')) ||
      (github.event_name == 'pull_request_review' && (contains(github.event.review.body, '@claude ') || github.event.review.body == '@claude')) ||
      (github.event_name == 'issues' && ((contains(github.event.issue.body, '@claude ') || github.event.issue.body == '@claude') || (contains(github.event.issue.title, '@claude ') || github.event.issue.title == '@claude')))
    permissions:
      contents: write
      pull-requests: write
      issues: write
      actions: read
      id-token: write
    uses: rysk-tanaka/workflows/.github/workflows/claude.yml@main
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### claude-code-review.yml

```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize, labeled, ready_for_review, reopened]

jobs:
  claude-review:
    if: |
      contains(github.event.pull_request.labels.*.name, 'claude-review')
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    uses: rysk-tanaka/workflows/.github/workflows/claude-code-review.yml@main
    with:
      track_progress: ${{ github.event.action != 'labeled' }}
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### issue-scan.yml

```yaml
name: Issue Scan

on:
  schedule:
    - cron: "50 0 * * *"
  workflow_dispatch:

concurrency:
  group: issue-scan
  cancel-in-progress: false

jobs:
  scan:
    permissions:
      issues: write
      contents: read
      id-token: write
    uses: rysk-tanaka/workflows/.github/workflows/issue-scan.yml@main
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### issue-implement.yml

Note: `claude_args` 内のモデル名（`claude-opus-4-6`）は、Issue 実装が長時間・高精度タスクであるため意図的に高性能モデルを指定している。新しい Claude モデルがリリースされた場合、この SKILL.md 自体のモデル名を更新する必要がある。

`{{PACKAGE_MANAGER}}` はステップ1で検出したパッケージマネージャー名に置換する（`pnpm`, `npm`, `yarn`, `none`）。Python/Rust の場合は `none` を使用する（reusable workflow 側で Node.js セットアップをスキップする）。

`{{SETUP_COMMAND}}` は Node.js 以外のプロジェクトで、ランタイムやツールのインストールが必要な場合に指定する。不要な場合（Node.js プロジェクト）は `setup_command` 行自体を省略する。

- Python (uv): `curl -LsSf https://astral.sh/uv/install.sh | sh && echo "$HOME/.local/bin" >> $GITHUB_PATH && uv sync`
- Python (pip): `pip install -e ".[dev]"`
- Rust: `rustup update stable`

`{{ALLOWED_TOOLS}}` は以下のルールで組み立てる。

共通部分（全プロジェクト共通）。

```text
Read,Edit,Write,Glob,Grep,Bash(git fetch origin *),Bash(git add *),Bash(git commit *),Bash(git checkout *),Bash(git push origin implement-issue-*),Bash(git status),Bash(git status *),Bash(git diff),Bash(git diff *),Bash(git log *),Bash(gh issue view *),Bash(gh pr create * --body-file *),Bash(gh pr edit * --add-label *)
```

パッケージマネージャー部分（`{{PM_TOOLS}}`）— ステップ3で確認した各コマンド（テスト/lint/format）から生成する。

- Node.js (pnpm): `Bash(pnpm install),Bash(pnpm install *),Bash(pnpm test),Bash(pnpm test *),Bash(pnpm lint),Bash(pnpm lint *),Bash(pnpm format),Bash(pnpm format *)`
- Node.js (npm): `Bash(npm install),Bash(npm install *),Bash(npm test),Bash(npm test *),Bash(npm run lint),Bash(npm run lint *),Bash(npm run format),Bash(npm run format *)`
- Node.js (yarn): `Bash(yarn install),Bash(yarn install *),Bash(yarn test),Bash(yarn test *),Bash(yarn lint),Bash(yarn lint *),Bash(yarn format),Bash(yarn format *)`
- Python (uv): `Bash(uv sync),Bash(uv sync *),Bash(uv run pytest),Bash(uv run pytest *),Bash(uv run ruff check *),Bash(uv run ruff format *)`
- Python (pip): `Bash(pip install *),Bash(pytest),Bash(pytest *),Bash(ruff check *),Bash(ruff format *)`
- Rust: `Bash(cargo build),Bash(cargo build *),Bash(cargo test),Bash(cargo test *),Bash(cargo clippy),Bash(cargo clippy *),Bash(cargo fmt),Bash(cargo fmt *)`

ユーザーがコマンドをカスタマイズした場合は、それに合わせて `Bash(...)` パターンを調整する。コマンドが「なし」の場合は該当する `Bash(...)` を除外する。

`{{PROMPT_COMMANDS}}` はステップ3で確認したコマンドから手順4〜6を組み立てる。コマンドが「なし」の手順は省略する。

```yaml
name: Issue Implement

on:
  issues:
    types: [labeled]

concurrency:
  group: issue-implement-${{ github.event.issue.number }}
  cancel-in-progress: false

jobs:
  implement:
    if: github.event.label.name == 'claude-implement' && github.event.issue.state == 'open'
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
    uses: rysk-tanaka/workflows/.github/workflows/issue-implement.yml@main
    with:
      package_manager: {{PACKAGE_MANAGER}}
      {{SETUP_COMMAND_LINE}}
      claude_args: '--max-turns 40 --model claude-opus-4-6 --allowed-tools "{{ALLOWED_TOOLS}},{{PM_TOOLS}}"'
      prompt: |
        Issue #${{ github.event.issue.number }} を実装し、PR を作成してください。

        手順:
        1. `gh issue view ${{ github.event.issue.number }}` で Issue の要件を確認する
        2. 作業ブランチを作成する: `git fetch origin implement-issue-${{ github.event.issue.number }}:implement-issue-${{ github.event.issue.number }} 2>/dev/null && git checkout implement-issue-${{ github.event.issue.number }} || git checkout -b implement-issue-${{ github.event.issue.number }}`
        3. 実装を行う
        {{PROMPT_COMMANDS}}
        {{NEXT_STEP}}. 変更をコミットして `git push origin implement-issue-${{ github.event.issue.number }}` でプッシュする（`-u` フラグ不可）
        {{NEXT_STEP+1}}. PR 本文を `/tmp/pr-body.md` に Write ツールで書き出し（必ず `Closes #${{ github.event.issue.number }}` を含める）、`gh pr create --title "..." --body-file /tmp/pr-body.md` で PR を作成する（`--body` は使用しない）
        {{NEXT_STEP+2}}. `gh pr edit --add-label claude-review` で PR に `claude-review` ラベルを付与する

        要件:
        - 既存のコーディング規約に従う
        - コミットメッセージは英語で Conventional Commits 形式、単一行にする（HEREDOC やマルチライン不可）
        - PR 本文は `.github/pull_request_template.md` のテンプレートに従う（該当しないセクションは省略可）
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

`{{PROMPT_COMMANDS}}` の組み立て例（Node.js pnpm でデフォルトの場合）。

```text
        4. `pnpm test` を実行してテストを確認する
        5. `pnpm lint` を実行して lint エラーがないことを確認する
        6. `pnpm format` を実行して整形する
```

`{{PROMPT_COMMANDS}}` の組み立て例（Python uv の場合）。

```text
        4. `uv run pytest` を実行してテストを確認する
        5. `uv run ruff check .` を実行して lint エラーがないことを確認する
        6. `uv run ruff format .` を実行して整形する
```

`{{SETUP_COMMAND_LINE}}` は `setup_command` が必要な場合に以下の行に置換する。不要な場合（Node.js プロジェクト）は行ごと削除する。

```text
      setup_command: "{{SETUP_COMMAND}}"
```

手順の番号は、省略されたコマンドがあっても連番になるよう調整する。`{{NEXT_STEP}}`、`{{NEXT_STEP+1}}`、`{{NEXT_STEP+2}}` は `{{PROMPT_COMMANDS}}` の最終手順番号 +1 から連番で置換する（`{{NEXT_STEP+1}}` はシンボル名であり、`{{NEXT_STEP}}` の値に1を加算した整数リテラルで置換する）。例えば `{{PROMPT_COMMANDS}}` が手順4〜6の3ステップを生成した場合: `{{NEXT_STEP}}` = 7、`{{NEXT_STEP+1}}` = 8、`{{NEXT_STEP+2}}` = 9。手順4〜5の2ステップのみなら: `{{NEXT_STEP}}` = 6、`{{NEXT_STEP+1}}` = 7、`{{NEXT_STEP+2}}` = 8。`{{PROMPT_COMMANDS}}` が空（全コマンド不要）の場合は手順3の直後からのため `{{NEXT_STEP}}` = 4、`{{NEXT_STEP+1}}` = 5、`{{NEXT_STEP+2}}` = 6 とする。

### auto-release.yml

`{{VERSION_SOURCE}}` はプロジェクトタイプから決定する。

- Node.js → `package_json`
- Python → `pyproject_toml`
- Rust → `cargo_toml`

`{{PATHS_TRIGGER}}` はプロジェクトタイプから決定する。

- Node.js → `['package.json']`
- Python → `['pyproject.toml']`
- Rust → `['Cargo.toml']`

`{{VERSION_EXTRACT}}` はバージョン取得コマンドで、プロジェクトタイプから決定する。Docker publish と Action メジャータグのテンプレートで使用する。

- Node.js → `jq -r '.version' package.json`
- Python → `grep -Po '(?<=^version = ")[^"]+' pyproject.toml`
- Rust → `grep -Po '(?<=^version = ")[^"]+' Cargo.toml`

Note: `validate-branch` ジョブは `workflow_dispatch` で非 main ブランチから誤実行された場合のガード。push トリガーでは常に main ブランチ制約があるため、主に手動実行の安全弁として機能する。

```yaml
name: Release

on:
  push:
    branches: [main]
    paths: {{PATHS_TRIGGER}}
  workflow_dispatch:

concurrency:
  group: auto-release-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: write

jobs:
  validate-branch:
    runs-on: ubuntu-latest
    steps:
      - name: Validate branch
        if: github.ref != 'refs/heads/main'
        run: |
          echo "::error::This workflow can only be run from the main branch (current: ${{ github.ref }})"
          exit 1

  create-release:
    needs: validate-branch
    permissions:
      contents: write
    uses: rysk-tanaka/workflows/.github/workflows/release-on-version-change.yml@main
    with:
      version_source: {{VERSION_SOURCE}}
      tag_prefix: v
      force_released_output: ${{ github.event_name == 'workflow_dispatch' }}
    secrets: inherit
```

publish 対象が選択された場合、以下のジョブを `create-release` の後に追加する。

#### npm publish（選択時のみ追加）

`pnpm` の場合は `corepack enable pnpm` の行をそのまま含め、`npm` または `yarn` の場合は除外して生成する。

```yaml
  npm:
    needs: create-release
    if: needs.create-release.outputs.released == 'true' && vars.PUBLISH_NPM == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - name: Check NPM_TOKEN
        run: |
          if [ -z "$NODE_AUTH_TOKEN" ]; then
            echo "::error::PUBLISH_NPM=true is set but NPM_TOKEN secret is missing"
            exit 1
          fi
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      - run: corepack enable pnpm
      - uses: actions/setup-node@v6
        with:
          node-version: 24
          cache: {{PACKAGE_MANAGER}}
          registry-url: https://registry.npmjs.org
      - run: {{INSTALL_COMMAND}}
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      - name: Publish to npm
        run: |
          PKG_NAME=$(jq -r '.name' package.json)
          PKG_VERSION=$(jq -r '.version' package.json)
          {{PUBLISH_COMMAND}} || {
            if npm view "${PKG_NAME}@${PKG_VERSION}" version > /dev/null 2>&1; then
              echo "Version ${PKG_VERSION} already published, skipping"
            else
              exit 1
            fi
          }
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

`{{INSTALL_COMMAND}}` と `{{PUBLISH_COMMAND}}` はパッケージマネージャーに応じて変更する。

- pnpm: `pnpm install --frozen-lockfile` / `pnpm publish --access public --no-git-checks`
- npm: `npm ci` / `npm publish --access public`
- yarn: `yarn install --frozen-lockfile` / `yarn publish --access public`

#### Docker publish（選択時のみ追加）

```yaml
  docker:
    needs: create-release
    if: needs.create-release.outputs.released == 'true' && vars.PUBLISH_DOCKER == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    env:
      IMAGE: ghcr.io/${{ github.repository }}
    steps:
      - uses: actions/checkout@v6
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Extract version for tags
        id: version
        run: |
          set -euo pipefail
          VERSION=$({{VERSION_EXTRACT}})
          if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
            echo "::error::Failed to extract version"
            exit 1
          fi
          MAJOR=$(echo "$VERSION" | cut -d. -f1)
          if [[ ! "$MAJOR" =~ ^[0-9]+$ ]]; then
            echo "::error::Invalid major version: $MAJOR"
            exit 1
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "major=$MAJOR" >> "$GITHUB_OUTPUT"
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.IMAGE }}:v${{ steps.version.outputs.version }}
            ${{ env.IMAGE }}:v${{ steps.version.outputs.major }}
            ${{ env.IMAGE }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

#### GitHub Action メジャータグ（選択時のみ追加）

```yaml
  update-major-tag:
    needs: create-release
    if: needs.create-release.outputs.released == 'true' && vars.PUBLISH_ACTION == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v6
      - name: Configure git identity
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
      - name: Update major version tag
        run: |
          set -euo pipefail
          MAJOR="v$({{VERSION_EXTRACT}} | cut -d. -f1)"
          if [[ ! "$MAJOR" =~ ^v[0-9]+$ ]]; then
            echo "::error::Invalid major version tag: $MAJOR"
            exit 1
          fi
          git tag -f "$MAJOR"
          git push origin "$MAJOR" --force
```

### dependabot-scan.yml

Note: このワークフローは Node.js プロジェクト専用。Python/Rust プロジェクトでは選択肢に表示しない。

`{{PACKAGE_MANAGER}}` はステップ1で検出した Node.js パッケージマネージャー名（`pnpm`, `npm`, `yarn`）に置換する。

```yaml
name: Dependabot Scan

on:
  workflow_dispatch:

jobs:
  scan:
    uses: rysk-tanaka/workflows/.github/workflows/dependabot-scan.yml@main
    with:
      package_manager: {{PACKAGE_MANAGER}}
```

## ステップ5: 完了報告

生成されたファイル一覧と、必要なセットアップのチェックリストを表示する。

### 表示テンプレート

```text
## 生成されたワークフロー

- `.github/workflows/claude.yml` ✅
- `.github/workflows/claude-code-review.yml` ✅
（選択されたもののみ表示）

## セットアップチェックリスト

### 必須
- [ ] `CLAUDE_CODE_OAUTH_TOKEN` シークレットを Settings > Secrets and variables > Actions に設定
- [ ] `rysk-tanaka/workflows` リポジトリの Settings > Actions > General > Access で、このリポジトリからのアクセスを許可

### リリース自動化（選択時のみ表示）
- [ ] （npm 選択時）`NPM_TOKEN` シークレットを設定
- [ ] （npm 選択時）`PUBLISH_NPM` リポジトリ変数を `true` に設定
- [ ] （Docker 選択時）`PUBLISH_DOCKER` リポジトリ変数を `true` に設定
- [ ] （Action 選択時）`PUBLISH_ACTION` リポジトリ変数を `true` に設定

### Issue 自動対応フロー（Issue Scan + Implement 選択時のみ表示）
- [ ] `mise run setup-review-label` を実行して `claude-review` ラベルを作成
- 他のラベル（`claude-scanned`, `difficulty/*`, `claude-implement`）は Issue Scan 初回実行時に自動作成されます
```

## 重要事項

- テンプレート内の `${{ }}` は GitHub Actions の式構文なのでそのまま出力する（変数展開しない）
- `{{PLACEHOLDER}}` は生成時にプロジェクト情報で置換するスキル内のプレースホルダー
- 既存ファイルがある場合は上書き確認を行う
- `.github/workflows/` ディレクトリが存在しない場合は `mkdir -p` で作成する
- ワークフローファイルの末尾には改行を入れる

$ARGUMENTS
