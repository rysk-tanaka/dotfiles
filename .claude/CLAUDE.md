# CLAUDE.md - Global Settings

This file provides global guidance to Claude Code (claude.ai/code) across all projects.

## Language

開発者は日本人なので、質問や回答は日本語で行う必要があります。

## General Development Preferences

### Communication Style
- 簡潔で明確な説明を心がける
- 技術的な内容も日本語で説明
- コード内のコメントは英語でも可

### Markdown Formatting Guidelines
- 箇条書き前のコロン（:）は使用しない（例: 「以下の項目:」→「以下の項目。」）
- 箇条書き内での不必要な太字（**）強調は避ける
- シンプルで読みやすい表記を優先する
- 人間によるレビューやメンテナンスがしやすいよう、シンプルな構造を保つ

#### Mermaid図表でのプレースホルダー表記
- **図表内**: 波括弧 `{}` を使用しない（HTMLタグとして解釈されるか、シンタックスエラーになる）
  - ✅ 正しい: `accel_data/uuid`, `path/to/gateway_id/uuid`
  - ❌ 誤り: `accel_data/{uuid}`, `path/to/{gateway_id}/{uuid}`
- **図表外の通常テキスト**: 波括弧でプレースホルダーを明示
  - 例: `accel_data/{uuid}`, `path/to/{gateway_id}/{uuid}`

### Code Quality Standards
- Clean, readable code with meaningful variable names
- Follow project-specific conventions when available
- Prioritize maintainability and clarity
- Always end files with a trailing newline (空行を末尾に追加)
  - 理由: POSIX標準への準拠、diffの見やすさ向上、多くのエディタ・ツールとの互換性確保

### Common Development Tools

#### Python Projects
- Virtual environment: `uv` (preferred) or `venv`
- Linting: `ruff` (preferred) or `flake8`
- Formatting: `ruff format` (preferred) or `black`
- Type checking: `mypy`
- Testing: `pytest`
- Type hints: For dictionaries, use `dict` without type parameters (e.g., `dict` instead of `Dict[str, Any]`)
  - Rationale: Dictionaries are typically used for flexible, general-purpose data structures

##### Testing with pytest
- **テストスタイル**: 関数ベースのテストを推奨（クラスベースより）
- **環境変数のモック**: `unittest.mock`より`monkeypatch`フィクスチャを使用
  - `monkeypatch.setenv(key, value)`: 環境変数の設定
  - `monkeypatch.delenv(key, raising=False)`: 環境変数の削除
  - 自動クリーンアップによりテスト間の分離が保証される
- **マジックナンバー**: ruff PLR2004ルールに従い、数値は意味のある定数として定義
- **副作用の回避**: テストでは実際のAPIリクエストやファイル操作を避け、モックを使用
- **モジュール再読み込み**: 環境変数やグローバル状態を変更した場合は`importlib.reload()`を使用

#### Version Control
- Git commit messages in English
- Follow Conventional Commits when specified
- Single-line commit messages preferred
- Pull request templates: Check `.github/workflows/pull_request_template.md`

### Important Instructions
- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files (*.md) unless explicitly requested

### File Operations Safety
- NEVER use `rm -rf` command unless explicitly requested by the user
- When removing symlinks, use `unlink` command instead of `rm`
- When removing directories, prefer specific paths over wildcards
- Always verify the target path before destructive operations

## Claude Code Settings Management

### Configuration File Locations
- **Global instructions**: `~/.claude/CLAUDE.md` (managed via symlink from this repository)
- **Other settings**: `~/.claude.json` (internally managed by Claude Code)

Note: Due to current implementation differences, Claude Code settings cannot be managed via symlinks like other configuration files. Use `claude config` commands for settings management.

## Project-Specific Settings

For project-specific settings, check the local CLAUDE.md file in the project repository.
