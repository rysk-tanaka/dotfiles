# cmux

AI コーディングエージェント向けのネイティブ macOS ターミナル。Ghostty のレンダリングエンジンをベースにしている。

- 公式サイト: <https://www.cmux.dev/>
- GitHub: <https://github.com/manaflow-ai/cmux>

## インストール

Brewfile に登録済み。`brew bundle` でインストールされる。

tap の追加が必要なため、Brewfile に `tap "manaflow-ai/cmux"` を記述している。

## 用語

- Window - macOS のウィンドウ。複数のワークスペースを持てる
- Workspace - ウィンドウ内の作業空間。cmd + 1〜8 で切り替え
- Pane - ワークスペース内の分割領域
- Surface - ペイン内のターミナルやブラウザの実体。サイドバーの縦タブに対応
- Panel - 通知パネルなどの UI 要素。上記の階層とは独立

階層構造: Window > Workspace > Pane > Surface

## ショートカット

Settings > Keyboard Shortcuts からカスタマイズ可能。ショートカットの値をクリックして新しいキーを録音する。Settings に表示されない操作（Close Surface など）は Ghostty 設定（`~/.config/ghostty/config`）の `keybind` で変更できる。

カスタム列は現在の設定。空欄はデフォルトのまま。

Window:

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| 新規ウィンドウ | cmd + shift + N | |
| ウィンドウを閉じる | ctrl + cmd + W | |

Workspace:

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| 新規ワークスペース | cmd + N | |
| ワークスペース切り替え | cmd + 1〜8 | |
| 最後のワークスペース | cmd + 9 | |
| 次のワークスペース | ctrl + cmd + ] | |
| 前のワークスペース | ctrl + cmd + [ | |
| ワークスペースを閉じる | cmd + shift + W | |
| ワークスペース名変更 | cmd + shift + R | |

Pane:

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| 右に分割 | cmd + D | cmd + → |
| 下に分割 | cmd + shift + D | cmd + ↓ |
| ペイン移動（左/右/上/下） | opt + cmd + 矢印 | |

Surface:

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| 新規サーフェス | cmd + T | |
| 次のサーフェス | cmd + shift + ] | |
| 前のサーフェス | cmd + shift + [ | |
| サーフェス切り替え | ctrl + 1〜8 | |
| 最後のサーフェス | ctrl + 9 | |
| サーフェスを閉じる | cmd + W | cmd + delete (Ghostty config) |
| タブ名変更 | cmd + R | |

Browser (Surface):

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| ブラウザサーフェスを開く | cmd + shift + L | |
| ブラウザを右に分割 | opt + cmd + D | |
| ブラウザを下に分割 | opt + shift + cmd + D | |
| アドレスバーにフォーカス | cmd + L | |
| ページ再読み込み | cmd + R | |
| 戻る/進む | cmd + [/] | |
| Developer Tools | opt + cmd + I | |
| JavaScript Console | opt + cmd + C | |

Panel:

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| 通知パネル表示 | cmd + I | |
| 未読にジャンプ | cmd + shift + U | |
| フォーカス中のパネルを点灯 | cmd + shift + H | |

その他:

| 操作 | デフォルト | カスタム |
| --- | --- | --- |
| サイドバー切り替え | cmd + B | |
| 検索 | cmd + F | |
| スクロールバック消去 | cmd + K | |

## CLI

- `cmux browser open [url]`: ブラウザサーフェスを開く
- `cmux new-pane --type browser --url <url>`: ブラウザペインを指定方向に追加
- `cmux close-surface --surface <id|ref>`: サーフェスを閉じる
- `cmux list-pane-surfaces`: サーフェス一覧を表示
- `cmux read-screen`: ターミナルの表示内容を読み取る
- `cmux browser snapshot`: ブラウザのアクセシビリティツリーを取得
- `cmux notify --title <text> --body <text>`: 通知を送信
- `cmux claude-hook <session-start|stop|notification>`: Claude Code フック連携

## Claude Code との連携

### 通知フック（claude-hook）

cmux は Claude Code 専用の `claude-hook` コマンドを提供している。Claude Code の hook stdin から JSON をそのまま受け取るため、`jq` でのパースが不要。

`~/.claude/settings.json` の hooks セクションに以下を追加する。

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "cmux claude-hook stop 2>/dev/null || true"
      }
    ]
  }
],
"Notification": [
  {
    "matcher": "idle_prompt|auth_success|elicitation_dialog",
    "hooks": [
      {
        "type": "command",
        "command": "cmux claude-hook notification 2>/dev/null || true"
      }
    ]
  }
]
```

発火タイミング。

| フック | 発火条件 |
| --- | --- |
| Stop | Claude Code セッションが完了したとき |
| Notification (idle_prompt) | エージェントが入力待ちになったとき |
| Notification (auth_success) | 認証が成功したとき |
| Notification (elicitation_dialog) | 確認ダイアログが表示されたとき |

cmux 以外のターミナルでは `/tmp/cmux.sock` が存在しないため、`2>/dev/null || true` で静かにスキップされる。

### ブラウザ操作（CLI 経由）

cmux 内蔵ブラウザを CLI から操作できる。開発中の Web アプリの動作確認に使える。

```bash
cmux browser open http://localhost:3000   # ブラウザサーフェスを開く
cmux browser snapshot                     # アクセシビリティツリーを取得
cmux browser navigate <url>               # URL に遷移
cmux browser eval <script>                # JavaScript を実行
cmux browser console list                 # コンソールログを取得
```

Playwright MCP と役割が似ているが、cmux 内蔵ブラウザを使う点が異なる。現時点では cmux 用の MCP サーバーは提供されていないため、Claude Code からは `Bash` ツール経由で実行する形になる（2026-02 時点）。

### 画面読み取り（read-screen）

別ペインのターミナル出力を読み取れる。

```bash
cmux read-screen                                  # 現在のサーフェス
cmux read-screen --surface <id|ref>               # 指定サーフェス
cmux read-screen --surface <id|ref> --scrollback   # スクロールバック含む
```

ユースケース: ペイン1で Claude Code を実行中に、ペイン2の開発サーバーのログやエラー出力を確認する。
