# CLAUDE.md - Global Settings

This file provides global guidance to Claude Code (claude.ai/code) across all projects.

## Language

開発者は日本人なので、質問や回答は日本語で行う必要があります。

## Communication Style

- 簡潔で明確な説明を心がける
- 技術的な内容も日本語で説明
- コード内のコメントは英語でも可

## Code Quality Standards

- 早期returnでネストを浅く保つ（ガード節パターン）
- 複雑な条件式は説明変数に分割して意図を明示する
  - Example: `is_eligible = user.is_active and user.age >= MIN_AGE`
- コメントは「何をするか」ではなく「なぜ必要か」を記述する
- ブール変数は肯定形で命名する（`is_active` ○ / `is_not_deleted` ✗）
- Always end files with a trailing newline (空行を末尾に追加)

## Version Control

- Git commit messages in English
- Follow Conventional Commits when specified
- Single-line commit messages preferred

## Important Instructions

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files (*.md) unless explicitly requested

## File Operations Safety

- NEVER use `rm -rf` command unless explicitly requested by the user
- When removing symlinks, use `unlink` command instead of `rm`
- When removing directories, prefer specific paths over wildcards
- Always verify the target path before destructive operations
