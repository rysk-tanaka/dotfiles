---
name: auto-commit
description: ステージ済みの変更からコミットメッセージを自動生成
allowed-tools: "Bash"
---

# コミットメッセージ自動生成

ステージ済みの変更を分析し、Conventional Commits形式のコミットメッセージを生成する。

## 手順

### 1. ステージ済み変更の確認

`git diff --cached --name-only` を実行し、ステージ済みのファイルがあるか確認する。

- 出力が空の場合はステージ済みの変更がないため、「ステージ済みの変更がありません。先に `git add` で変更をステージしてください。」と報告して終了

### 2. コミット履歴の参照

`git log --oneline -10` を実行し、直近のコミットメッセージのスタイル（スコープの命名規則等）を把握する。

### 3. 変更内容の分析

#### 3a. 変更の概要を取得

`git diff --cached --stat` を実行し、変更ファイルの一覧と行数の概要を取得する。

#### 3b. 詳細な差分を取得

`git diff --cached` で詳細な差分を取得する。ただし以下を考慮する。

- lockファイル（`package-lock.json`, `yarn.lock`, `uv.lock`, `Gemfile.lock`, `poetry.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `composer.lock` 等）は除外する
  - `git diff --cached -- . ':!*lock*'` のように pathspec で除外
- stat の結果で特定のファイルの変更行数が500行を超えている場合、そのファイルは stat の要約のみで判断し、詳細 diff からは除外する

### 4. コミットメッセージ候補の生成

以下のルールに従って、2-4個のコミットメッセージ候補を生成する。
各候補はニュアンスや着眼点を変えて、異なる表現を提示する。

#### 形式

```text
type(scope): description
```

#### type の選択基準

- `feat` - 新機能の追加
- `fix` - バグ修正
- `docs` - ドキュメントのみの変更
- `style` - コードの意味に影響しない変更（空白、フォーマット等）
- `refactor` - バグ修正でも機能追加でもないコード変更
- `perf` - パフォーマンス改善
- `test` - テストの追加・修正
- `chore` - ビルドプロセスや補助ツールの変更

#### scope の決定

- 直近のコミット履歴で使われているスコープを参考にする
- 変更が単一のコンポーネント/ディレクトリに限定される場合はそれをスコープにする
- 変更が広範囲にわたる場合はスコープを省略可

#### description のルール

- 英語で記述
- 先頭は小文字
- 末尾にピリオドを付けない
- 命令形で記述（add, update, fix 等）
- 簡潔に（50文字以内を目安）

### 5. JSON出力

候補を以下のJSON形式で出力する。JSON以外のテキスト（説明文など）は一切出力しない。

- `candidates` - 候補の配列
  - `message` - コミットメッセージ本文
  - `description` - 候補の意図・ニュアンスの違い（日本語）

```json
{
  "candidates": [
    {"message": "fix(auth): handle expired token refresh", "description": "トークン更新処理の修正に着目"},
    {"message": "fix(auth): add token expiry handling", "description": "期限切れハンドリングの追加として表現"}
  ]
}
```

メッセージに AI ツールの署名やCo-Authored-By は含めない。
