---
name: read-screen
description: cmuxの別ペインのターミナル出力を読み取る (user)
argument-hint: <surface-id|ref> [--workspace <ref>] [--lines <n>] | --list [--workspace <ref>]
allowed-tools:
  # ~ is not expanded in allowed-tools patterns (claude-code#14956)
  - Bash(bash /Users/rysk/.claude/skills/read-screen/read-screen.sh *)
---

# cmux ペイン読み取り

別ペインのターミナル出力を読み取る。デフォルトで直近100行を取得する。

## 入力

`$ARGUMENTS` にサーフェスIDまたはrefが渡される。裸の数値（例: `7`）は自動的に `surface:7` に変換される。

- 第1引数（必須、リストモード以外）: サーフェスIDまたはref（`surface:7` でも `7` でも可）
- `--workspace <ref>`（省略可）: ワークスペース指定（`workspace:1` でも `1` でも可）
- `--lines <n>`（省略時: 100）: 取得する行数
- `--list`: サーフェス一覧を表示

## 手順

### 1. 引数の確認

`$ARGUMENTS` にサーフェスIDが含まれている場合は、直接読み取りに進む（手順3へ）。

`$ARGUMENTS` が空、`--list` のみ、またはユーザーがどのペインを読むか指定していない場合は、一覧を取得する。

```bash
bash /Users/rysk/.claude/skills/read-screen/read-screen.sh --list
```

出力からユーザーに対象サーフェスを確認する。

### 2. ターミナル出力の読み取り

```bash
bash /Users/rysk/.claude/skills/read-screen/read-screen.sh $ARGUMENTS
```

### 3. 結果の報告

取得した出力をそのまま表示する。エラーログや例外が含まれている場合は要約して報告する。
