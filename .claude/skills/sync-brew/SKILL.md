---
name: sync-brew
description: Brewfileにアプリを追加（セクション自動判定、auto_updates確認）
allowed-tools:
  - Bash(brew info *)
  - Bash(brew list *)
  - Bash(brew leaves *)
  - Bash(brew bundle *)
  - Read
  - Edit
---

# Brewfile同期

アプリ名を受け取り、Brewfileに適切なセクションで追加します。

## 入力

`$ARGUMENTS` にスペース区切りでアプリ名が渡されます。

## 手順

以下の手順を各アプリ名に対して実行してください。

### 1. パッケージの確認

`brew info --json=v2 <name>` を実行し、以下を確認する。

- パッケージが存在するか
- formula か cask か
- 説明（desc）
- auto_updates の有無（cask のみ）

cask が見つからない場合は `brew info --json=v2 --cask <name>` も試す。

### 2. Brewfileの読み取り

dotfilesリポジトリのBrewfileを読み取り、既存のセクション構造を把握する。

### 3. 重複チェック

既にBrewfileに登録されている場合はスキップし、その旨を報告する。

### 4. セクション判定

パッケージの種類と説明から最適なセクションを判断する。

- formula の場合
  - zsh/shell関連 → "Shell plugins (required by .zshrc)" セクション
  - それ以外 → "CLI tools" セクション
- cask の場合
  - Brewfileの既存セクション名とアプリの説明を照合し、最も適切なセクションに追加
  - 既存セクションに該当しない場合は新規セクションを作成（"# Fonts" の前に配置）

### 5. Brewfileへの追加

Editツールを使い、該当セクション内にアルファベット順で追記する。

- formula: `brew "<name>"` 形式
- cask: `cask "<name>"` 形式

### 6. auto_updates確認と移行コマンド出力

auto_updatesが false の cask について、以下のメッセージを出力する（実行はしない）。

```text
Migration required (no auto_updates):
  brew install --cask --force <name>
```

## 結果報告

処理結果を以下の形式で報告する。

- 追加したパッケージ名、セクション、auto_updates有無
- スキップしたパッケージ（重複、未発見など）
- 移行が必要なパッケージのコマンド一覧

## インストール確認

結果報告の後、AskUserQuestion ツールでインストールを確認する。

- question: `brew bundle でインストールを実行しますか？`
- options: `["yes", "no"]`

ユーザーが同意した場合のみ `brew bundle` を実行する。
