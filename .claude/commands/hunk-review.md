# Hunk ライブレビュー

ユーザーが別ターミナルで起動している Hunk（terminal diff viewer）のライブセッションを操作し、変更内容を案内するレビューを行う。

## 手順

1. `hunk skill path` を実行して同梱 skill（SKILL.md）のパスを取得する
2. その SKILL.md を読み込み、以降はその内容に従って `hunk session *` コマンドでレビューを進める

## 注意

- `hunk diff` や `hunk show` などの対話型 TUI コマンドは実行しない（TUI はユーザー用。エージェントは `hunk session *` のみ使用する）
- アクティブなセッションが無い場合は、ユーザーに別ターミナルで `hunk diff`（または `hunk diff --watch`）を起動してもらう
- skill はインストール済みバイナリに同梱されているため、常にバージョン一致した手順が得られる
- コメントの summary は画面上で1行に切り詰められるため短文（40文字程度まで）にし、詳細な意図や背景は rationale に書く

## 引数

$ARGUMENTS が指定された場合はレビュー対象や観点の指示として扱う（例: 特定ファイルのみ、`show HEAD~1` のリロードなど）。
