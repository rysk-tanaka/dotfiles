# CLAUDE.md - Global Settings

This file provides global guidance to Claude Code (claude.ai/code) across all projects.

## Language

開発者は日本人なので、質問や回答は日本語で行う必要があります。

## General Development Preferences

### Communication Style
- 簡潔で明確な説明を心がける
- 技術的な内容も日本語で説明
- コード内のコメントは英語でも可

### Code Quality Standards
- Clean, readable code with meaningful variable names
- Follow project-specific conventions when available
- Prioritize maintainability and clarity

### Common Development Tools

#### Python Projects
- Virtual environment: `uv` (preferred) or `venv`
- Linting: `ruff` (preferred) or `flake8`
- Formatting: `ruff format` (preferred) or `black`
- Type checking: `mypy`
- Testing: `pytest`

#### Version Control
- Git commit messages in English
- Follow Conventional Commits when specified
- Single-line commit messages preferred

### Important Instructions
- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files (*.md) unless explicitly requested

## Project-Specific Settings

For project-specific settings, check the local CLAUDE.md file in the project repository.