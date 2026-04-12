# Brewfile

Homebrew パッケージの宣言的管理。`Brewfile` に定義したパッケージを `brew bundle` で一括インストールします。

## 概要

リポジトリルートの `Brewfile` で macOS にインストールするパッケージを管理しています。

- formula（CLI ツール）、cask（GUI アプリ）、tap、mas（Mac App Store）に対応
- セクションコメントで用途別に分類
- `brew bundle` で Brewfile の内容をインストール（`mise install` と同等の位置づけ）

## Brewfile の構造

```text
# セクション名
brew "formula-name"
cask "cask-name"
tap "user/repo"
mas "App Name", id: 123456
```

セクションはアプリの用途別に分類されています。各セクション内はアルファベット順で記載します。

## 基本コマンド

```bash
# Brewfile のパッケージをインストール
brew bundle

# Brewfile の内容が全てインストール済みか確認
brew bundle check

# Brewfile にないインストール済みパッケージを表示
brew bundle cleanup

# 実際にアンインストール
brew bundle cleanup --force
```

## パッケージの追加

### Claude Code スキル（推奨）

`/sync-brew <app-name>` スキルで追加できます。セクションの自動判定、重複チェック、`auto_updates` の確認を行います。

### 手動追加

1. `brew info <name>` で formula か cask かを確認
2. Brewfile の該当セクションにアルファベット順で追記
3. `brew bundle` でインストール

## 差分の確認

`mise run scan-brew` で、インストール済みパッケージと Brewfile の差分を確認できます。

```bash
mise run scan-brew
```

以下の2つの差分を表示します。

- Installed but not in Brewfile -- インストール済みだが Brewfile に未登録
- In Brewfile but not installed -- Brewfile に記載があるが未インストール

`auto_updates` フラグを持つ cask は Homebrew 管理外で自動更新されるため、`brew list --cask` に表示されない場合があります。`scan-brew` はこれを検出し `(auto_updates, managed outside brew)` と表示します。

## auto_updates について

一部の cask は `auto_updates` フラグを持ち、アプリ自身が更新を管理します（例: Arc, Slack, Discord）。

- `brew upgrade` の対象外となる
- `brew install --cask` で初回インストール後はアプリ側の更新機構に委ねられる
- `brew list --cask` に表示されない場合がある（Homebrew の管理対象外となるため）

既にアプリとしてインストール済みの cask を Homebrew 管理に移行するには、`--force` オプションが必要です。

```bash
brew install --cask --force <name>
```

## mise との使い分け

| 項目 | Brewfile (`brew bundle`) | mise (`mise install`) |
| --- | --- | --- |
| 管理対象 | macOS アプリ、システムツール | 開発ツール、ランタイム |
| バージョン管理 | なし（常に最新） | バージョンピン留め |
| 自動更新 | Renovate 対象外 | Renovate で PR 自動作成 |
| インストール先 | `/opt/homebrew/` | `~/.local/share/mise/` |

Homebrew は macOS のパッケージマネージャとして GUI アプリやシステムレベルのツールを管理し、mise はプロジェクト単位の開発ツールを管理します。一部のツール（例: `gnupg`, `coreutils`）は mise では配布されていないため Homebrew で管理しています。

## 参考

- [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle)
- [Homebrew Docs](https://docs.brew.sh/)
