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

Note: Python files are auto-linted via PostToolUse hook after Edit/Write. Manual lint is only needed for final verification.

## Architecture Overview

This is a dotfiles repository that manages macOS configuration files through symlinks. The architecture consists of:

1. Configuration Storage: All dotfiles are stored in this repository under their respective paths
2. Symlink Management: Manual creation of symlinks from the repository to their expected system locations
3. Tool Management: mise handles installation and version management of development tools. Versions are pinned in `.config/mise/config.toml` and updated via Renovate (`renovate.json`). Exceptions: `node` (lts), `claude-code` (latest) are not tracked by Renovate. Renovate PR release notes are automatically summarized in Japanese via `renovate-translate.yml`
4. Project Integration: The `setup-links` task allows other projects to inherit coding standards and configurations
5. Documentation: Detailed guides are in `docs/` (claude-code, mcp, renovate, etc.)

## Claude Code Custom Skills

Located in `.claude/skills/`. Skill metadata is maintained in `.claude/skills/catalog.json`. When adding or updating skills, update catalog.json as well. Skills with shell scripts require permission entries in two places with different pattern formats.

- `.claude/settings.json` `permissions.allow` → colon format: `Bash(bash /Users/rysk/.claude/skills/<name>/<script>:*)`
- SKILL.md `allowed-tools` → space format: `Bash(bash /Users/rysk/.claude/skills/<name>/<script> *)`

Note: These use different pattern engines. The `~` home directory shorthand is not expanded in `allowed-tools` patterns (claude-code#14956), so absolute paths are required. For `Read` permissions in settings.json, the `//` prefix is the correct format (e.g., `Read(//Users/rysk/.cache/claude-bg/**)`) — this is not a typo.

Skills that also run as mise tasks (auto-commit, suggest-branch) use the collect.sh pattern: a shell script pre-collects git data as JSON, which is passed to the LLM in a single API call via `<git-data>` tags. The SKILL.md includes a fallback to run collect.sh when data is not provided in the prompt.

Dual-mode skills (resolve-review, codex-review) support foreground (default) and background (`--bg` flag) execution. Foreground mode runs synchronously and processes results immediately. Background mode uses a two-phase pattern: the launch phase starts the shell script with `run_in_background` and returns immediately, while the result processing phase triggers automatically when a background task completion system-reminder is detected (or when the user explicitly requests results). Background mode allows multiple skills to run concurrently. Results are cached to `~/.cache/claude-bg/` for session loss recovery (e.g., `codex-review-{session-id}.txt`).

## Project Integration

When running `mise run setup-links` in other projects, the following are symlinked:

- `.pre-commit-config.yaml` - Pre-commit hooks (prek/pre-commit 共用)
- `.markdownlint-cli2.jsonc` - Markdown lint config
- `.mcp.json` - MCP server settings
- `.claudeignore` - Claude Code context exclusion (caches, build artifacts, etc. to reduce file tree snapshot tokens)

Symlinks are tracked in `~/.config/mise/linked-repos/` for bulk management.

## Claude Code Hooks

Located in `.claude/hooks/`, configured in `.claude/settings.json` under `hooks`.

- UserPromptSubmit (`suggest-effort.sh`) - Analyzes prompt complexity via keyword scoring and suggests effort level adjustments. Outputs plain text to stdout (not JSON, to avoid claude-code#17550). Must complete in < 100ms.
- PostToolUse - Auto-lints Python files after Edit/Write (inline command in settings.json)
- Notification - macOS notification via osascript on idle_prompt/auth_success/elicitation_dialog

## Permission Boundaries

The following operations are blocked in `.claude/settings.json` deny rules.

- `git add -A`, `git add --all`, `git add .` - always stage specific files instead
- `rm -rf` - destructive removal blocked
- Reading `.env*`, `~/.aws/credentials`, `~/.gnupg/**`, `~/.ssh/**` - sensitive files blocked

## Code Style

- Shell scripts: Bash, use shellcheck for validation
- Python: Python 3.12 with type hints, format with ruff, type-check with mypy/ty/pyright
- Commit messages: Follow conventional commits (feat, fix, docs, chore)
- Pre-commit hooks: `end-of-file-fixer` and `trailing-whitespace` run automatically on commit
