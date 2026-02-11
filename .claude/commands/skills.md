# スキル一覧

`.claude/skills/catalog.json` を読み取り、ジャンル別に整理して出力してください。

## 出力形式

category ごとにスキルをグループ化し、以下の形式で出力する。

```text
## <category>

/<name> - <description>
  例: <example>
```

- example がないスキルには使用例を付けない
- 各 category 内は name のアルファベット順でソート
- 余計な説明は不要。一覧のみ出力
