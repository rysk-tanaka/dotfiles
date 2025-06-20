# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- **Lint Python code:** `mise run lint` or `ruff format && ruff check && mypy .`
- **Setup project symlinks:** `mise run setup-links` (creates symlinks for PR template and coding rules)
- **Install tools:** `mise install` (installs all tools defined in `.config/mise/config.toml`)

## Architecture Overview

This is a dotfiles repository that manages macOS configuration files through symlinks. The architecture consists of:

1. **Configuration Storage**: All dotfiles are stored in this repository under their respective paths
2. **Symlink Management**: Manual creation of symlinks from the repository to their expected system locations
3. **Tool Management**: mise handles installation and version management of development tools
4. **Project Integration**: The `setup-links` task allows other projects to inherit coding standards

## Managed Configurations

The repository manages dotfiles for these tools:
- **Terminal**: Ghostty (`~/.config/ghostty/config`)
- **Shell**: Zsh (`~/.zshrc`, `~/.zprofile`) with custom aliases
- **Version Control**: Git (`~/.gitconfig`, `~/.config/git/ignore`)
- **Editors**: Vim (`~/.vimrc`), Zed (`~/.config/zed/`)
- **Prompt**: Starship (`~/.config/starship.toml`)
- **Tool Management**: mise (`~/.config/mise/config.toml`)

## Zsh Aliases

Key productivity aliases defined in `.zshrc`:
- `le`, `lt`, `la`, `ll` - Various eza listing formats
- `ruffc`, `rufff` - Shortcuts for ruff check/format
- `mr` - Shortcut for `mise run`
- `gc`, `gs`, `gp` - Git shortcuts

## Code Style
- **Shell scripts**: POSIX-compliant, use shellcheck for validation
- **Python**: Python 3.12 with type hints, format with ruff, type-check with mypy
- **Commit messages**: Follow conventional commits (feat, fix, docs, chore)