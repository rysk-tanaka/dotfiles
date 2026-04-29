# uvでPythonプロジェクトを作成

uvを使用して新しいPythonプロジェクトを `src/` レイアウトで初期化し、pyproject.tomlにツール設定を自動追加してください。

## ステップ1: 対話的に情報収集

以下をユーザーに質問する（AskUserQuestionを使用）。AskUserQuestionは1回あたり最大4問なので、2回に分けて呼び出す。

1. Pythonバージョン（選択肢: 3.13 / 3.14）
2. ruffのルールセット（選択肢: 基本 / モダン / ALL）
   - 基本: B, BLE, C4, E, F, W
   - モダン: E, W, F, UP, B, I, C90, PLR
   - ALL: 全ルール有効化（個別除外）
3. 型チェッカー（選択肢: ty / mypy）
4. AWS SDK (boto3) を使用するか（はい / いいえ）
5. Pydantic を使用するか（はい / いいえ）

## ステップ2: プロジェクト初期化

1. 既にpyproject.tomlが存在する場合は警告して中止
2. `uv init <project-name> --python <version> --package --build-backend hatch` でプロジェクト作成（引数なしなら現在ディレクトリで `uv init --python <version> --package --build-backend hatch`）

`--package --build-backend hatch` により `src/<project>/` レイアウト・`[build-system]`・`[tool.hatch.build.targets.wheel]` が自動生成される。venv は後続の `uv add` / `uv sync` 実行時に自動作成されるため、明示的な `uv venv` は不要。

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
    "B008",  # Do not perform function calls in argument defaults (typer pattern)
    "B027",  # Empty method in abstract base class without abstract decorator (optional hooks)
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
    "B008",    # Do not perform function calls in argument defaults (typer pattern)
    "B027",    # Empty method in abstract base class without abstract decorator (optional hooks)
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
    "B008",   # Do not perform function calls in argument defaults (typer pattern)
    "B027",   # Empty method in abstract base class without abstract decorator (optional hooks)
    "E501",   # Line too long
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101"]
```

### 型チェッカー設定

tyを選択した場合、dev依存にtyを追加する（設定セクションは不要）。

mypyを選択した場合、以下の共通設定を追加する。

```toml
[tool.mypy]
exclude = ["build/"]
```

`follow_imports = "skip"` をグローバル指定すると内部モジュールの型解析まで緩むため使用しない。スキップが必要な依存はoverridesで個別に指定する。

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

### coverage設定

`src/` レイアウトでcoverageがパッケージを正しく検出するために必要。

```toml
[tool.coverage.run]
source = ["<project-name>"]
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

tyを選択した場合。

```bash
uv add --group dev pytest pytest-cov ruff ty
```

mypyを選択した場合。

```bash
uv add --group dev pytest pytest-cov ruff mypy
```

## ステップ5: ディレクトリ構造の作成

- `tests/` ディレクトリを作成
- `tests/__init__.py` を作成（改行1文字のみ。Writeツールで空文字列を渡すと改行なしになるので注意）
- `tests/test_placeholder.py` を作成（`uv run pytest` が即座に動作するように）

`tests/test_placeholder.py` はパッケージをimportする形にする。`assert True` のみだとcoverageが「Module never imported」「No data was collected」「Failed to generate report」の3つのwarningを出すため。`<project_name>` はプロジェクト名（ハイフンはアンダースコアに変換）に置き換える。

```python
import <project_name>


def test_placeholder():
    assert <project_name> is not None
```

## ステップ6: 同期と完了

1. `uv sync` で依存関係同期（dev依存はデフォルトで含まれる。`--all-extras` は `[project.optional-dependencies]` 用なのでここでは不要）
2. `uv run pytest` を実行してテストが通ることを確認
3. 作成されたプロジェクト構成を表示
4. 次のステップとして `uv run pytest` や `uv run ruff check .` の実行方法を案内

## 重要事項

- 既にpyproject.tomlが存在する場合は警告して中止
- エラーが発生した場合は適切にハンドリングして報告
- pyproject.tomlの追記はEditツールで末尾に追加する（uv initが生成した内容を壊さない）
- pytest設定の `--cov=` にはプロジェクト名（ハイフンをアンダースコアに変換）を指定する
- `src/` レイアウトを使用する（`uv init --package` が自動生成）
- `authors` フィールドは `uv init` がgit configから埋めるが、空にしたい場合は **行ごと削除する**（hatchlingは `{ name = "" }` のような空文字列を `ValueError` で拒否しビルドが失敗する。setuptoolsでは通るので注意）

$ARGUMENTS
