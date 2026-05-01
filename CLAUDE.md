# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Lint Python code: `mise run lint` or `mise run lint -- <paths>` (paths optional, defaults to current directory)
- Lint Markdown: `mdlint .` (shell function, auto-detects git root config)
- Setup project symlinks: `mise run setup-links` (creates symlinks, then run `prek install` for git hooks)
- Remove project symlinks: `mise run cleanup-links` (removes symlinks from current repo)
- Remove specific link globally: `mise run cleanup-link <name>` (removes from all registered repos)
- Install Homebrew packages: `brew bundle` (installs packages and fonts defined in `Brewfile`)
- Install tools: `mise install` (installs all tools defined in `.config/mise/config.toml`)
- Setup WakaTime: `mise run setup-wakatime` (generates `~/.wakatime.cfg` from 1Password)
- Install fonts: `mise run setup-fonts` or `bash .config/mise/tasks/setup-fonts` (installs Bizin Gothic NF from GitHub Releases)
- Scan Brewfile: `mise run scan-brew` (shows diff between installed packages and Brewfile)
- Setup Claude token: `mise run setup-claude-token` (sets `CLAUDE_CODE_OAUTH_TOKEN` secret on current GitHub repo)
- Setup review label: `mise run setup-review-label` (creates `claude-review` label on current GitHub repo)
- Suggest branch name: `mise run suggest-branch` (analyzes work and suggests branch names)
- Upgrade Claude Code: `mise run upgrade-claude` (upgrades to latest GitHub Release, bypassing aqua registry lag)

Note: Python files are auto-linted via PostToolUse hook after Edit/Write. Manual lint is only needed for final verification.

## Architecture Overview

This is a dotfiles repository that manages macOS configuration files through symlinks. The architecture consists of:

1. Configuration Storage: All dotfiles are stored in this repository under their respective paths. Codex CLI 関連は `.codex/` 配下（`config.toml`, `skills/`）。`~/.codex/AGENTS.md` は `~/.claude/CLAUDE.md` へのシンボリックリンクで共通化
2. Symlink Management: Manual creation of symlinks from the repository to their expected system locations. `~/.claude/{CLAUDE.md,commands,rules,scripts,skills}` is symlinked to `.claude/*` here, so global Claude Code state lives in this repo
3. Tool Management: mise handles installation and version management of development tools. Versions are pinned in `.config/mise/config.toml` and updated via Renovate (`renovate.json`). Exceptions: `node` (lts), `claude-code` (aqua backend, pinned) are not tracked by Renovate. Renovate PR release notes are automatically summarized in Japanese via `renovate-translate.yml`
4. Project Integration: The `setup-links` task allows other projects to inherit coding standards and configurations
5. Documentation: Detailed guides are in `docs/` (claude-code, mcp, renovate, etc.)
6. Terminal Integration: Zed editor terminals use tmux for session persistence. `.config/tmux/zed-attach.sh` assigns each Zed terminal tab to a unique tmux window via lock files, preserving scrollback across editor restarts

## Claude Code Rules

Located in `.claude/rules/` with `paths` frontmatter for file-pattern scoping.

- `python.md` - Python type hints, error handling, pytest, Pydantic V2 conventions (applies to `**/*.py`, `**/pyproject.toml`, `**/requirements*.txt`)
- `markdown.md` - No colons before lists, no bold, code block language specs, Mermaid placeholder rules (applies to `**/*.md`, `**/*.mdx`)
- `design-decisions.md` - Design decision recording priorities: deterministic tools > tests > CLAUDE.md > code comments (applies to `**/CLAUDE.md`, `**/AGENTS.md`, `**/docs/**`)

## Claude Code Custom Skills

Located in `.claude/skills/`. `~/.claude/skills` はこのディレクトリへの symlink (`~/.claude/{CLAUDE.md,commands,rules,scripts}` も同様)。**user スコープと project スコープが同一パスに解決される** ため、`gh skill install --scope user` でも dotfiles に書き込まれる。catalog.json への追記もセットで必要。

現在定義されている skill 一覧とメタデータは `.claude/skills/catalog.json` が単一の情報源。skill を追加・更新する際は catalog.json も必ず更新する。外部 skill (`mizchi/skills` 等) を `gh skill install <repo> <name> --agent claude-code` で導入する場合も catalog.json への登録が必要 (frontmatter の `metadata.github-*` で `gh skill update` 追従可能)。Skills with shell scripts require permission entries in two places with different pattern formats.

- `.claude/settings.json` `permissions.allow` → colon format: `Bash(bash /Users/rysk/.claude/skills/<name>/<script>:*)`
- SKILL.md `allowed-tools` → space format: `Bash(bash /Users/rysk/.claude/skills/<name>/<script> *)`

Note: These use different pattern engines. The `~` home directory shorthand is not expanded in `allowed-tools` patterns (claude-code#14956), so absolute paths are required. For `Read` permissions in settings.json, the `//` prefix is the correct format (e.g., `Read(//Users/rysk/.cache/claude-bg/**)`) — this is not a typo.

Skills that also run as mise tasks (auto-commit, suggest-branch) use the collect.sh pattern: a shell script pre-collects git data as JSON, which is passed to the LLM in a single API call via `<git-data>` tags. The SKILL.md includes a fallback to run collect.sh when data is not provided in the prompt.

Dual-mode skills (resolve-review, codex-review) support foreground (default) and background (`--bg` flag) execution. Foreground mode runs synchronously and processes results immediately. Background mode uses a two-phase pattern: the launch phase starts the shell script with `run_in_background` and returns immediately, while the result processing phase triggers automatically when a background task completion system-reminder is detected (or when the user explicitly requests results). Background mode allows multiple skills to run concurrently. Results are cached to `~/.cache/claude-bg/` for session loss recovery (e.g., `codex-review-{session-id}.txt`).

## Claude Code Commands

Located in `.claude/commands/`. Lightweight prompts that don't need a full skill directory. Invoked via `/command-name`.

- `check-bg` - バックグラウンドタスク結果確認
- `permalink` - GitHub パーマリンク生成
- `uv-init` - uv で Python プロジェクト初期化

## Shell Functions

カスタムシェル関数は `.config/mise/shell-functions.sh` に集約。`mdlint`（markdownlint-cli2 ラッパー）, `mermaidlint`（Mermaid 構文チェック）, `build_lambda`（Docker 用 SSH 設定切替付き Lambda ビルド）, `teleport`（SSH Host Alias 環境向け `claude --teleport` ラッパー）等。追加・編集はこのファイルで行う。

## Pull Request Guidelines

PR template is at `.github/pull_request_template.md`. Key conventions are as follows.

- Title: concise Japanese (technical terms in English are OK)
- Body: ですます調, sections: 変更の概要 / 主な変更点 / 変更の背景 / 補足
- Add `claude-review` label to request Claude Code Action review

## Project Integration

When running `mise run setup-links` in other projects, the following are symlinked:

- `.pre-commit-config.yaml` - Pre-commit hooks (prek/pre-commit 共用)
- `.markdownlint-cli2.jsonc` - Markdown lint config
- `.mcp.json` - MCP server settings (GitHub MCP requires `GH_MCP_TOKEN` env var, set via `.zshenv`)
- `.claudeignore` - Claude Code context exclusion (caches, build artifacts, etc. to reduce file tree snapshot tokens)

Symlinks are tracked in `~/.config/mise/linked-repos/` for bulk management.

## Claude Code Hooks

Located in `.claude/hooks/`, configured in `.claude/settings.json` under `hooks`.

- UserPromptSubmit (`suggest-effort.sh`) - Analyzes prompt complexity via keyword scoring and suggests effort level adjustments. Outputs plain text to stdout (not JSON, to avoid claude-code#17550). Must complete in < 100ms.
- PostToolUse - Auto-lints Python files after Edit/Write (inline command in settings.json)
- Stop - cmux claude-hook でセッション完了を通知（cmux 以外のターミナルでは静かにスキップ）
- Notification - cmux claude-hook で idle_prompt/auth_success/elicitation_dialog を通知（cmux 以外のターミナルでは静かにスキップ）

## Permission Boundaries

The following operations are blocked in `.claude/settings.json` deny rules.

- `git add -A`, `git add --all`, `git add .` - always stage specific files instead
- `rm -rf` - destructive removal blocked
- Reading `.env*`, `~/.aws/credentials`, `~/.gnupg/**`, `~/.ssh/**` - sensitive files blocked

## GitHub Workflows

- `claude-code-review.yml` - `claude-review` ラベル付きPRでClaude Code Reviewを実行（PR作成・更新・ラベル付与・ドラフト解除・reopenで発火）
- `claude.yml` - Issue/PRコメント・PRレビュー・Issue作成で `@claude` メンションすると汎用Claude Codeが応答
- `mise-install.yml` - `.config/mise/config.toml` 変更PRで `mise install` を実行（Renovate automergeの安全弁、Rulesetで必須チェック化）
- `renovate-translate.yml` - Renovate BotのPRリリースノートを日本語に要約してコメント投稿

Note: ワークフロー内の `actions/checkout@v6`, `actions/setup-node@v6` は正しいバージョン。v6 は 2025年にリリース済み（知識カットオフによる誤検知に注意）。

## Code Style

- Shell scripts: Bash, use shellcheck for validation
- Python: Python 3.12 with type hints, format with ruff, type-check with mypy/ty/pyright
- Commit messages: Follow conventional commits (feat, fix, docs, chore)
- Pre-commit hooks: `end-of-file-fixer` and `trailing-whitespace` run automatically on commit
