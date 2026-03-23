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

`$ARGUMENTS` にサーフェスIDまたはrefが渡される。

- 第1引数（必須、リストモード以外）: サーフェスIDまたはref
- `--workspace <ref>`（省略可）: 対象ワークスペース
- `--lines <n>`（省略時: 100）: 取得する行数
- `--list`: サーフェス一覧を表示（`--workspace` 指定時はそのワークスペースのみ、省略時は全ワークスペース）

## 手順

### 1. サーフェス一覧の確認（IDが不明な場合）

`$ARGUMENTS` が空、またはユーザーがどのペインを読むか指定していない場合は、まず一覧を取得する。

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
