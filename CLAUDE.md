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
- Auto commit: `mise run auto-commit` or `/auto-commit` in session (generates commit message from staged changes)
- Suggest branch: `mise run suggest-branch` or `/suggest-branch` in session (suggests branch name from current changes)
- Create PR: `/pr` or `/pr <base-branch>` in session (creates pull request from branch changes)
- Resolve review: `/resolve-review` or `/resolve-review <PR number>` in session (fetches and addresses PR review comments)
- Await CI: `/await-ci` or `/await-ci <PR number>` in session (checks CI status and optionally waits for completion)

Note: Python files are auto-linted via PostToolUse hook after Edit/Write. Manual lint is only needed for final verification.

## Architecture Overview

This is a dotfiles repository that manages macOS configuration files through symlinks. The architecture consists of:

1. Configuration Storage: All dotfiles are stored in this repository under their respective paths
2. Symlink Management: Manual creation of symlinks from the repository to their expected system locations
3. Tool Management: mise handles installation and version management of development tools
4. Project Integration: The `setup-links` task allows other projects to inherit coding standards and configurations

## Key Components

### Managed Configurations

- Terminal: Ghostty (`~/.config/ghostty/config`)
- Shell: Zsh (`~/.zshrc`, `~/.zprofile`) with custom aliases
- Version Control: Git (`~/.gitconfig`, `~/.config/git/ignore`)
- Editors: Vim (`~/.vimrc`), Zed (`~/.config/zed/`)
- Prompt: Starship (`~/.config/starship.toml`)
- Package Management: Homebrew (`Brewfile` - CLI tools, desktop apps, fonts)
- Tool Management: mise (`~/.config/mise/config.toml`)
- Claude Code: Global settings, commands, skills, scripts (all symlinked from this repo to `~/.claude/`)
- ccmanager: Session management (`~/.config/ccmanager/config.json`)

### Custom Shell Functions

Defined in `.config/mise/shell-functions.sh` and auto-loaded via `.zshrc`:

- `mdlint` - markdownlint-cli2 wrapper that auto-detects git root config
- `mermaidlint` - Validates Mermaid syntax in Markdown files
- `build_lambda` - Docker Lambda build wrapper with 1Password SSH agent support
- `teleport` - Claude Code teleport wrapper for SSH Host Alias environments

### Claude Code Custom Commands

Located in `.claude/commands/`:

- `/permalink` - Generate GitHub permalink
- `/uv-init` - Initialize Python project with uv
- `/claude-check`, `/claude-monitor`, `/claude-clean` - Process management

### Claude Code Custom Skills

Located in `.claude/skills/`.

- `/cloudwatch-logs` - Fetch CloudWatch logs (Python script with boto3)
- `/sync-brew` - Add apps to Brewfile with auto-categorization
- `/auto-commit` - Generate commit message from staged changes and commit
- `/suggest-branch` - Suggest branch name from current changes or work description
- `/pr` - Create pull request from branch changes
- `/resolve-review` - Resolve PR review comments
- `/await-ci` - Check CI status and wait for completion

## Project Integration

When running `mise run setup-links` in other projects, the following are symlinked:

- `.github/workflows/pull_request_template.md` - PR template
- `.pre-commit-config.yaml` - Pre-commit hooks (prek/pre-commit 共用)
- `.markdownlint-cli2.jsonc` - Markdown lint config
- `.mcp.json` - MCP server settings

Symlinks are tracked in `~/.config/mise/linked-repos/` for bulk management.

## mise Tasks

File-based tasks are located in `.config/mise/tasks/`:

- `setup-links` - Create symlinks and register to tracking
- `cleanup-links` - Remove all symlinks from current repo
- `cleanup-link` - Remove specific link from all registered repos (with confirmation)
- `setup-wakatime` - Generate WakaTime config from 1Password
- `setup-fonts` - Install Bizin Gothic NF from GitHub Releases
- `scan-brew` - Show differences between installed packages and Brewfile

## Zsh Aliases

Key productivity aliases defined in `.zshrc`:

- `le`, `lt` - eza listing with git info
- `tree` - eza tree view
- `ruffc`, `rufff` - ruff check/format
- `mr` - `mise run`
- `diff` - delta

## Code Style

- Shell scripts: Bash, use shellcheck for validation
- Python: Python 3.12 with type hints, format with ruff, type-check with mypy/ty/pyright
- Commit messages: Follow conventional commits (feat, fix, docs, chore)
