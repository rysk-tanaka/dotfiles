# DevPod

devcontainer 仕様に準拠したオープンソースの開発環境マネージャ。ローカル Docker、SSH、Kubernetes 等をプロバイダとして利用できる。

- 公式サイト: <https://devpod.sh/>
- GitHub: <https://github.com/loft-sh/devpod>

## インストール

Brewfile に登録済み。`brew bundle` でインストールされる。

## 初期設定

```bash
devpod provider add docker
devpod provider use docker
```

## 基本操作

```bash
devpod up .               # devcontainer を起動
devpod up . --ide none     # IDE を起動せずにコンテナのみ起動
devpod up . --recreate     # イメージを再ビルドして起動
devpod ssh .               # コンテナに SSH 接続
devpod stop .              # コンテナを停止
devpod delete .            # コンテナを削除
devpod list                # ワークスペース一覧
```

## SSH agent forwarding

private リポジトリへの SSH 認証が必要な場合、ホスト側で SSH 鍵を agent に登録しておく。

```bash
ssh-add
```

DevPod が自動でコンテナに転送する。

## Zed との接続

DevPod は各ワークスペースの SSH エントリを `~/.ssh/config` に自動追加する。Zed の Remote SSH でそのまま接続できる。

1. コンテナを IDE なしで起動する

   ```bash
   devpod up . --ide none
   ```

2. Zed で `Cmd+Shift+P` → **"projects: open remote"** を選択

3. 対象の devcontainer ホスト（例: `unaas-database.devpod`）を選択

4. ワークスペースディレクトリ `/workspace` を入力

## Claude Code との組み合わせ

devcontainer 内のターミナルで Claude Code を実行できる。サンドボックス環境のため `--dangerously-skip-permissions` を安心して使える。

```bash
claude --dangerously-skip-permissions
```
