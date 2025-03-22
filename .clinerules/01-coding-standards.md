# コーディング標準

## Python コードの品質管理

### Lintツール

本プロジェクトでは、以下のツールを使用してコード品質を確保します：

#### Ruff

Ruffは高速なPython linterで、コードスタイルチェックとフォーマットに使用します。

- **実行方法**: `ruff check .` または `ruff format .`
- **設定ファイル**: プロジェクトルートの`pyproject.toml`に設定

pyproject.toml の設定例

```toml
[tool.ruff]
line-length = 100
exclude = ["**/node_modules", "**/__pycache__", "venv*", "package*"]

[tool.ruff.lint]
ignore = [
    "B008", # Do not perform function calls in argument defaults
    "E203", # Whitespace before ':'
    "E266", # Too many leading '#'
    "E501", # Line too long (82 > 79 characters)
    "F403", # 'from module import *' used; unable to detect undefined names
    "F401", # Module imported but unused
    "E722", # do not use bare except (viewsに存在、不要か検討の余地あり)
    "F811", # Redefinition of unused name from line n (settingsに存在、不要か検討の余地あり)
    "E731", # Do not assign a lambda expression, use a def
    "F821", # Undefined name name
]
select = [
    "B",  # flake8-bugbear
    "C",  # flake8-comprehensions
    "E",  # pycodestyle errors
    "F",  # flake8 pyflakes
    "W",  # pycodestyle warnings
    "B9", # flake8-blind-except
]
```

#### Mypy

Mypyは静的型チェッカーで、型アノテーションのチェックに使用します。

- **実行方法**: `mypy .`
- **設定ファイル**: プロジェクトルートの`pyproject.toml`に設定

pyproject.toml の設定例

```toml
[tool.mypy]
exclude = ["build/"]
plugins = ["pydantic.mypy"]
follow_imports = "skip"

[[tool.mypy.overrides]]
module = ["boto3", "boto3.*", "botocore", "botocore.*"]
ignore_missing_imports = true
```

### 環境管理とパッケージ

#### uv

本プロジェクトではuvを使用してPython環境とパッケージを管理します。

- **新規環境の作成**: `uv venv`
- **パッケージのインストール**: `uv pip install .`
- **依存関係の追加**: `uv add package_name`

##### 推奨事項

- 新しい依存関係を追加する際は、必ず`pyproject.toml`に追記してください
- 開発環境では`uv pip install -e .`を使用して開発モードでインストールしてください

### Lintルールの適用

- すべての新規コードは、これらのlintツールをパスしなければなりません
- 例外的にルールを無視する場合は、コメントで理由を明記してください

### IDE設定と警告の取り扱い

#### VSCode Pylance

VSCodeのPylance拡張機能を使用する際の注意事項：

- **インポート関連の警告**: Pylanceが出力するインポート関連のエラー（赤い波線）については、以下の場合は無視してください：
  - `pyproject.toml`で管理されている依存パッケージの場合
  - 実行時にはパスが正しく解決される動的インポートの場合

- **警告の検証方法**: Pylanceの警告が出ていても、以下の条件を満たす場合は無視してよい：
  - Ruffのチェックでエラーが出ていない
  - 実際のプログラム実行時にインポートエラーが発生しない

- **優先度**: 以下の優先順位で警告を扱ってください：
  1. mypy のエラーは常に修正すること（最優先）
  2. Ruff のエラーは修正すること（高優先）
  3. Pylance のインポート警告は実動作に問題なければ無視可（低優先）
