# uvでPythonプロジェクトを作成

uvを使用して新しいPythonプロジェクトを初期化し、pyproject.tomlにツール設定を自動追加してください。

## ステップ1: 対話的に情報収集

以下をユーザーに質問する（AskUserQuestionを使用）。

1. Pythonバージョン（選択肢: 3.12 / 3.13）
2. ruffのルールセット（選択肢: 基本 / モダン / ALL）
   - 基本: B, BLE, C4, E, F, W
   - モダン: E, W, F, UP, B, I, C90, PLR
   - ALL: 全ルール有効化（個別除外）
3. AWS SDK (boto3) を使用するか（はい / いいえ）
4. Pydantic を使用するか（はい / いいえ）

## ステップ2: プロジェクト初期化

1. 既にpyproject.tomlが存在する場合は警告して中止
2. `uv init <project-name> --python <version>` でプロジェクト作成（引数なしなら現在ディレクトリで `uv init --python <version>`）
3. `uv venv` で仮想環境を作成

## ステップ3: pyproject.toml に設定セクションを追記

`uv init` が生成した pyproject.toml の末尾に以下を追記する。

### ruff設定

ユーザーが選んだルールセットに応じて設定する。

基本ルールセットの場合。

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = [
    "B",    # flake8-bugbear
    "BLE",  # flake8-blind-except
    "C4",   # flake8-comprehensions
    "E",    # pycodestyle errors
    "F",    # pyflakes
    "W",    # pycodestyle warnings
]
ignore = [
    "B008",  # Do not perform function calls in argument defaults
    "E501",  # Line too long
]
```

モダンルールセットの場合。

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # Pyflakes
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "I",    # isort
    "C90",  # mccabe complexity
    "PLR",  # Pylint refactoring
]
ignore = [
    "PLR2004", # Magic value comparison
]

[tool.ruff.lint.mccabe]
max-complexity = 10

[tool.ruff.lint.pylint]
max-args = 8
max-branches = 15
max-statements = 50
max-returns = 6
```

ALLルールセットの場合。

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = ["ALL"]
ignore = [
    "D",      # pydocstyle
    "N815",   # Variable mixedCase in class scope
    "COM812", # missing-trailing-comma
    "INP001", # Add an `__init__.py`
    "ISC001", # single-line-implicit-string-concatenation
    "B008",   # Do not perform function calls in argument defaults
    "E501",   # Line too long
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101"]
```

### mypy設定

共通設定。

```toml
[tool.mypy]
exclude = ["build/"]
follow_imports = "skip"
```

Pydantic使用時のみ追加。

```toml
plugins = ["pydantic.mypy"]
```

AWS SDK使用時のみ追加。

```toml
[[tool.mypy.overrides]]
module = ["boto3", "boto3.*", "botocore", "botocore.*"]
ignore_missing_imports = true
```

### pytest設定

`<project-name>` はプロジェクト名（ハイフンはアンダースコアに変換）に置き換える。

共通設定。

```toml
[tool.pytest.ini_options]
addopts = "--cov=<project-name>"
testpaths = ["tests"]
python_files = ["test_*.py"]
```

AWS SDK使用時のみ追加。

```toml
filterwarnings = ["ignore:datetime.datetime.utcnow:DeprecationWarning:botocore"]
```

## ステップ4: 開発用パッケージの追加

```bash
uv add --group dev pytest pytest-cov ruff mypy
```

## ステップ5: ディレクトリ構造の作成

- `tests/` ディレクトリを作成
- `tests/__init__.py` を作成（空ファイル、末尾改行のみ）

## ステップ6: 同期と完了

1. `uv sync --all-extras` で依存関係同期
2. 作成されたプロジェクト構成を表示
3. 次のステップとして `uv run pytest` や `uv run ruff check .` の実行方法を案内

## 重要事項

- 既にpyproject.tomlが存在する場合は警告して中止
- エラーが発生した場合は適切にハンドリングして報告
- pyproject.tomlの追記はEditツールで末尾に追加する（uv initが生成した内容を壊さない）
- pytest設定の `--cov=` にはプロジェクト名（ハイフンをアンダースコアに変換）を指定する

$ARGUMENTS
