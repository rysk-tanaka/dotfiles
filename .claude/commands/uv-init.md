# uvでPythonプロジェクトを作成

uvを使用して新しいPythonプロジェクトを初期化してください。以下の手順で実行してください。

1. プロジェクトディレクトリの確認
   - 引数でプロジェクト名が指定された場合はそのディレクトリを作成
   - 引数がない場合は現在のディレクトリで初期化
2. プロジェクト初期化
   - `uv init` でプロジェクトを初期化（引数指定時は `uv init <project-name>`）
3. 仮想環境作成
   - `uv venv` で仮想環境を作成
4. 開発用パッケージの追加
   - `uv add --group dev pytest ruff mypy` で開発用依存関係を追加
5. 依存関係の同期
   - `uv sync --all-extras` で全依存関係をインストール
6. 完了メッセージ
   - 作成されたプロジェクトの構成を表示
   - 次のステップとして `uv run pytest` などの実行方法を案内

重要事項。

- Pythonのバージョンはpyproject.tomlのrequires-pythonに従う
- 既にpyproject.tomlが存在する場合は警告して中止
- エラーが発生した場合は適切にハンドリングして報告

$ARGUMENTS
