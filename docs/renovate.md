# Renovate

依存関係の自動更新ツール。GitHub App（Mend Renovate）として動作し、バージョン更新のPRを自動作成します。

## 概要

[Mend Renovate](https://github.com/apps/renovate) をGitHub Appとしてインストールして運用しています。

- スケジュール: 毎週土曜の午前9時（JST）まで
- Dependency Dashboard: リポジトリの issue として作成され、検出された更新の一覧と状態を確認できる
- PRには `dependencies` ラベルが自動付与される

## 設定ファイル

リポジトリルートの `renovate.json` で設定を管理しています。

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "enabledManagers": ["github-actions", "mise", "pre-commit"],
  "labels": ["dependencies"],
  "timezone": "Asia/Tokyo",
  "schedule": ["before 9am on saturday"],
  "packageRules": [
    {
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    },
    {
      "matchManagers": ["mise"],
      "matchDepNames": ["python"],
      "allowedVersions": "~3.12"
    },
    {
      "matchManagers": ["mise"],
      "matchDepNames": ["npm:ccusage", "npm:@ccusage/codex"],
      "groupName": "ccusage"
    }
  ]
}
```

各フィールドの説明。

- `extends` - `config:recommended` で推奨プリセットを適用（range更新なし等）
- `enabledManagers` - 有効にするマネージャを限定。対応しているマネージャは以下の3つ
  - `github-actions` - `.github/workflows/` 内のアクションバージョン
  - `mise` - `.config/mise/config.toml` のツールバージョン
  - `pre-commit` - `.pre-commit-config.yaml` のフックバージョン
- `labels` - 作成されるPRに付与するラベル
- `timezone` / `schedule` - 更新チェックのスケジュール

### packageRules

`packageRules` でマネージャ・パッケージごとの挙動をカスタマイズできます。

上記の設定例では以下の3ルールを定義しています。

- マイナー・パッチ更新を自動マージ。メジャー更新（破壊的変更の可能性）のみ手動レビュー対象となる
- Python のバージョンを `~3.12`（3.12.x の範囲）に制限。3.13 以降への自動更新PRが作成されなくなる
- `ccusage` と `@ccusage/codex` を `groupName` でグループ化。同一モノレポから公開されるパッケージのため、1つのPRにまとめる

パッケージの指定には `matchDepNames` を使用します。以前は `matchPackageNames` が使われていましたが、Renovate v39 以降は `matchDepNames` に統一されています。

## miseマネージャとの連携

Renovateの [mise マネージャ](https://docs.renovatebot.com/modules/manager/mise/) は `.config/mise/config.toml` の `[tools]` セクションからバージョンがピン留めされたツールを検出します。

### バージョンピン留めの要件

miseマネージャはセマンティックバージョニングに従う具体的なバージョン文字列のみを追跡対象とします。以下のような指定は検出対象外です。

- `latest` - 最新版の動的指定
- `lts` - LTSの動的指定
- パスやURL指定

このリポジトリでは以下の2ツールが追跡対象外となっています。

| ツール | バージョン指定 | 理由 |
| --- | --- | --- |
| node | `lts` | LTS追従で十分なため |
| claude-code | `latest` | 常に最新版を使用するため |

それ以外のツールはバージョンがピン留めされており、Renovateの追跡対象です。

### 対応するツールバックエンド

miseマネージャは以下のバックエンドのツールを検出します。

- 標準ツール（`python = "3.12.12"` 等）
- `aqua:` プレフィックス
- `cargo:` プレフィックス
- `npm:` プレフィックス

## Dependency Dashboard

Renovateはリポジトリに "Dependency Dashboard" という issue を自動作成します。

- 検出された依存関係と現在のバージョン、最新バージョンを一覧表示
- チェックボックスで個別に更新PRの作成を手動トリガーできる
- スケジュール外のタイミングで更新したい場合に便利

## PRマージ後のローカル対応

Renovate PRをマージした後、ローカル環境を同期するには以下を実行します。

```bash
git pull
mise upgrade
```

`mise upgrade` は新しいバージョンのインストールと旧バージョンのアンインストールを自動で行います。`mise install`（インストールのみ）+ `mise prune`（不要バージョン削除）を個別に実行する必要はありません。

`mise prune` は `~/.local/state/mise/tracked-configs` に登録された全リポジトリの設定を参照するため、他リポジトリで使用中のバージョンを誤って削除するリスクがあります。`mise upgrade` は対象ツールのバージョン変更のみを扱うため、この問題が起きません。

## ローカル実行

`renovate` コマンドの `--platform=local` オプションでローカル環境から実行できます。設定の検証や更新チェックの確認に便利です。

### 基本的な使い方

```bash
# 設定の検証と検出結果の確認（extractのみ）
LOG_LEVEL=debug npx renovate --platform=local --dry-run=extract

# レジストリへの問い合わせまで実施（lookupまで）
LOG_LEVEL=debug npx renovate --platform=local --dry-run=lookup

# 全処理を実行（PRは作成されない、ローカルブランチが作られる）
LOG_LEVEL=debug npx renovate --platform=local --dry-run=full
```

### dryRunモード

| モード | 動作内容 |
| --- | --- |
| extract | 設定ファイルの解析とパッケージ検出のみ |
| lookup | extract + レジストリへの最新バージョン問い合わせ |
| full | lookup + ブランチ作成（PRは作成しない） |

### GitHubトークンの有無

- トークンなし: パブリックレジストリへの問い合わせは可能だが、GitHub API のレート制限に達しやすい
- トークンあり: `GITHUB_TOKEN` または `GITHUB_COM_TOKEN` を設定するとレート制限が緩和される

```bash
# トークンを指定して実行
GITHUB_COM_TOKEN=$(gh auth token) LOG_LEVEL=debug npx renovate --platform=local --dry-run=lookup
```

### 別プロジェクトでの活用

`--platform=local` はリポジトリに `renovate.json` がなくても実行できます。依存関係の更新状況を一時的に確認したい場合に使えます。

```bash
# 任意のプロジェクトディレクトリで実行
cd /path/to/project
LOG_LEVEL=debug npx renovate --platform=local --dry-run=lookup
```

## 参考

- [Renovate Docs](https://docs.renovatebot.com/)
- [Mend Developer Portal](https://developer.mend.io/) - GitHub App のダッシュボード、ログ確認
- [mise manager - Renovate Docs](https://docs.renovatebot.com/modules/manager/mise/)
- [Configuration Options - Renovate Docs](https://docs.renovatebot.com/configuration-options/)
