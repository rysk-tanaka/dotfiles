---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/uv.lock"
  - "**/requirements*.txt"
---

# Python Development Rules

## Tools and Environment

- Virtual environment: `uv` (preferred) or `venv`
- Command execution: Always use `uv run` to execute Python commands (pytest, ruff, mypy, etc.)
  - Rationale: `uv run` automatically manages the virtual environment, preventing errors from running commands without activation
  - Example: `uv run pytest` instead of `source .venv/bin/activate && pytest`
- Linting: `ruff` (preferred) or `flake8`
- Formatting: `ruff format` (preferred) or `black`
- Type checking: `mypy`, `ty`, `pyright`
- Testing: `pytest`

## Type Hints

- For dictionaries, use `dict` without type parameters (e.g., `dict` instead of `Dict[str, Any]`)
  - Rationale: Dictionaries are typically used for flexible, general-purpose data structures
- Union types: Use pipe operator (`X | Y`) instead of `Optional[X]` or `Union[X, Y]`
  - Example: `str | None` instead of `Optional[str]`
  - Rationale: PEP 604 syntax is more concise and readable (available since Python 3.10)
- Python 3.14+: Do NOT use `from __future__ import annotations`
  - Rationale: PEP 649 makes deferred evaluation the default behavior
- Python 3.10-3.13: Only needed for forward references (e.g., class referencing itself)
- `__init__.py` files: Keep empty by default (only trailing newline)
  - Rationale: Modern Python doesn't require explicit exports in `__init__.py`

## Error Handling

- サービス層での例外処理: カスタムエラーメッセージで例外を再ラップしない
  - 例外はそのまま伝播させる（`except Exception: raise`）
  - コンテキスト情報（S3キー、パラメータ名など）はhandler層でログ出力
  - Rationale: エラーメッセージの重複を避け、スタックトレースを保持
- handler層の責務: ビジネスコンテキストを含めたログ出力とエラーハンドリング

## Testing with pytest

- テストスタイル: 関数ベースのテストを推奨（クラスベースより）
- 環境変数のモック: `unittest.mock`より`monkeypatch`フィクスチャを使用
  - `monkeypatch.setenv(key, value)`: 環境変数の設定
  - `monkeypatch.delenv(key, raising=False)`: 環境変数の削除
  - 自動クリーンアップによりテスト間の分離が保証される
- マジックナンバー: ruff PLR2004ルールに従い、数値は意味のある定数として定義
  - Example: `MAX_TIME_DIFF_SECONDS = 60` instead of hardcoded `60`
  - Constants should use UPPER_SNAKE_CASE naming convention
- 副作用の回避: テストでは実際のAPIリクエストやファイル操作を避け、モックを使用
- モジュール再読み込み: 環境変数やグローバル状態を変更した場合は`importlib.reload()`を使用

## Pydantic V2 (when applicable)

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
