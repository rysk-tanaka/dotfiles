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
- 太字（**）は使用しない
- シンプルで読みやすい表記を優先する
- 人間によるレビューやメンテナンスがしやすいよう、シンプルな構造を保つ

#### コードブロックの言語指定（MD040）

- すべてのコードブロックに言語指定を付ける（--fix で自動修正不可）
- 言語指定の選択基準
  - プログラミング言語: `python`, `typescript`, `bash`, `hcl` など
  - 設定ファイル: `json`, `yaml`, `toml`, `ini` など
  - ディレクトリ構造: `tree`
  - 説明テキスト、クエリパターン、擬似コード: `text`
  - シェル出力、ログ: `text` または `console`

#### テーブルスタイル（MD060）

- パイプの前後にスペースを入れる（spaced スタイル）
- セパレータ行も同様: `| --- | --- |`

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
- 早期returnでネストを浅く保つ（ガード節パターン）
- 複雑な条件式は説明変数に分割して意図を明示する
  - Example: `is_eligible = user.is_active and user.age >= MIN_AGE`
- コメントは「何をするか」ではなく「なぜ必要か」を記述する
- ブール変数は肯定形で命名する（`is_active` ○ / `is_not_deleted` ✗）
- Always end files with a trailing newline (空行を末尾に追加)
  - 理由: POSIX標準への準拠、diffの見やすさ向上、多くのエディタ・ツールとの互換性確保

### Common Development Tools

#### Python Projects

- Virtual environment: `uv` (preferred) or `venv`
- **Command execution**: Always use `uv run` to execute Python commands (pytest, ruff, mypy, etc.) instead of manually activating the virtual environment
  - Rationale: `uv run` automatically manages the virtual environment, preventing errors from running commands without activation
  - Example: `uv run pytest` instead of `source .venv/bin/activate && pytest`
- Linting: `ruff` (preferred) or `flake8`
- Formatting: `ruff format` (preferred) or `black`
- Type checking: `mypy`, `ty`, `pyright`
- Testing: `pytest`
- Type hints: For dictionaries, use `dict` without type parameters (e.g., `dict` instead of `Dict[str, Any]`)
  - Rationale: Dictionaries are typically used for flexible, general-purpose data structures
  - Union types: Use pipe operator (`X | Y`) instead of `Optional[X]` or `Union[X, Y]`
    - Example: `str | None` instead of `Optional[str]`
    - Rationale: PEP 604 syntax is more concise and readable (available since Python 3.10)
  - Python 3.14+: Do NOT use `from __future__ import annotations`
    - Rationale: PEP 649 makes deferred evaluation the default behavior
  - Python 3.10-3.13: Only needed for forward references (e.g., class referencing itself)
- `__init__.py` files: Keep empty by default (only trailing newline)
  - Rationale: Modern Python doesn't require explicit exports in `__init__.py`

##### Error Handling

- **サービス層での例外処理**: カスタムエラーメッセージで例外を再ラップしない
  - 例外はそのまま伝播させる（`except Exception: raise`）
  - コンテキスト情報（S3キー、パラメータ名など）はhandler層でログ出力
  - Rationale: エラーメッセージの重複を避け、スタックトレースを保持
- **handler層の責務**: ビジネスコンテキストを含めたログ出力とエラーハンドリング

##### Testing with pytest

- **テストスタイル**: 関数ベースのテストを推奨（クラスベースより）
- **環境変数のモック**: `unittest.mock`より`monkeypatch`フィクスチャを使用
  - `monkeypatch.setenv(key, value)`: 環境変数の設定
  - `monkeypatch.delenv(key, raising=False)`: 環境変数の削除
  - 自動クリーンアップによりテスト間の分離が保証される
- **マジックナンバー**: ruff PLR2004ルールに従い、数値は意味のある定数として定義
  - Example: `MAX_TIME_DIFF_SECONDS = 60` instead of hardcoded `60`
  - Constants should use UPPER_SNAKE_CASE naming convention
- **副作用の回避**: テストでは実際のAPIリクエストやファイル操作を避け、モックを使用
- **モジュール再読み込み**: 環境変数やグローバル状態を変更した場合は`importlib.reload()`を使用

##### Pydantic V2 (when applicable)

- Field validation: Use `Field()` with constraints (e.g., `ge=0`, `le=100`)
  - Example: `Field(..., ge=0, le=16777215, description="RGB color value")`
- Serialization: Use `@field_serializer` decorator instead of deprecated `json_encoders`
  - Example:

    ```python
    @field_serializer("timestamp")
    def serialize_timestamp(self, value: datetime) -> str:
        return value.isoformat()
    ```

  - Rationale: `json_encoders` is deprecated in Pydantic V2
- datetime handling: Use `datetime.now(UTC)` instead of deprecated `datetime.utcnow()`
  - Example: `Field(default_factory=lambda: datetime.now(UTC))`
  - Rationale: `datetime.utcnow()` is deprecated in Python 3.12+

#### Version Control

- Git commit messages in English
- Follow Conventional Commits when specified
- Single-line commit messages preferred
- Pull request templates: Check `.github/workflows/pull_request_template.md`
- コミットメッセージに以下を含めない
  - `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
  - `Co-Authored-By: Claude <noreply@anthropic.com>`

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
