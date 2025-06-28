# プルリクエスト作成

GitHubにプルリクエストを作成してください。以下の手順で実行してください：

1. 現在の変更状態を確認（git status -uno, git diff, git diff main...HEAD）
2. 現在のブランチを確認し、mainブランチの場合は適切なfeature/またはfix/ブランチを作成
3. 必要に応じてコミットを作成（単行のコミットメッセージを使用、git add は個別ファイル指定で行い -A オプションは使用しない）
4. mainブランチに誤ってコミットした場合は、git reset --soft HEAD~1 で取り消す
5. .github/workflows/pull_request_template.md を参照してPR本文を作成
6. ブランチをリモートにプッシュ（git push -u origin <branch-name>）
7. プルリクエストを作成（gh pr create）
8. 作成されたPRのURLを表示

重要：

- ブランチ名はfeature/またはfix/プレフィックスを使用
- コミットメッセージは1行で簡潔に
- PRテンプレートの形式に従って日本語で説明を記載
- PR本文に「🤖 Generated with [Claude Code](https://claude.ai/code)」を追加しない
- コミットメッセージに「Co-Authored-By: Claude <noreply@anthropic.com>」を追加しない
- 未追跡ファイルは無視される（git status -uno を使用）

$ARGUMENTS
