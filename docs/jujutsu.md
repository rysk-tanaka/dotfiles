# Jujutsu (jj) クイックリファレンス

Jujutsu は Git 互換の新しいバージョン管理システム。

## Gitとの主な違い

1. ワーキングコピーが自動的にコミットになる（`git add` 不要）
2. Change ID という安定した識別子がある（リベースしても変わらない）
3. コンフリクトがあってもコミット可能
4. 全操作が `jj undo` で取り消し可能

## 基本コマンド

```bash
# リポジトリのクローン
jj git clone <URL>

# 既存のGitリポジトリをjjで初期化
jj git init

# colocateモード（推奨）
# .jjと.gitを同じディレクトリに配置し、gitコマンドも併用可能
jj git init --colocate

# 状態確認
jj status        # jj st
jj log
jj diff

# コミット説明を追加
jj describe -m "message"    # jj desc

# 新しいチェンジを開始
jj new
jj new -m "message"

# 変更を親コミットに統合
jj squash

# 特定のコミットを編集モードにする
jj edit <change-id>
```

## ブランチ操作（bookmark）

```bash
# ブックマーク一覧
jj bookmark list    # jj b list

# ブックマーク作成
jj bookmark create <name>

# ブックマーク移動
jj bookmark move <name> --to <revision>

# リモートへプッシュ
jj git push
```

## 履歴操作

```bash
# リベース
jj rebase -s <source> -d <destination>

# 操作履歴
jj op log

# 取り消し
jj undo

# コミットの破棄
jj abandon <change-id>
```

## コンフリクト解決

```bash
# コンフリクトのあるコミットの上に新しいチェンジを作成
jj new <conflicted-change-id>

# ファイルを編集して解決後、親に統合
jj squash
```

## revset（リビジョン指定）

```bash
@           # 現在のワーキングコピー
@-          # 親コミット
root()      # ルートコミット
bookmarks() # 全ブックマーク
::@         # 現在までの全祖先
@::         # 現在からの全子孫

# 例: masterから現在までのログ
jj log -r 'master::@'
```

## Git連携

```bash
# リモートからフェッチ
jj git fetch

# プッシュ
jj git push

# Gitエクスポート（.git更新）
jj git export
```

## 参考リンク

- [公式ドキュメント](https://docs.jj-vcs.dev/)
- [チュートリアル](https://docs.jj-vcs.dev/latest/tutorial/)
- [Steve Klabnik のチュートリアル](https://steveklabnik.github.io/jujutsu-tutorial/)
