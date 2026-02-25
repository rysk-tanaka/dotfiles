# MCP（Model Context Protocol）設定

Claude CodeはMCPサーバーを使って外部ツールやサービスと連携できます。

## 利用可能なMCPサーバー

### AWS Documentation MCP Server

AWSドキュメントへのアクセスを提供します。

- コマンド: `uvx awslabs.aws-documentation-mcp-server@latest`
- スコープ: プロジェクト
- 機能: AWS認証不要でドキュメントの閲覧・検索が可能

### AWS API MCP Server

AWS CLIコマンドの実行を提供します。

- コマンド: `uvx awslabs.aws-api-mcp-server@latest`
- スコープ: プロジェクト
- 機能: 自然言語からAWS CLIコマンドを生成・実行
- 設定: `READ_OPERATIONS_ONLY=true`（読み取り専用モード）
- 前提条件: AWS認証情報の設定（AWS CLI/SDKの設定に従う）

### Playwright MCP Server

ブラウザ自動化機能を提供します。

- コマンド: `pnpm dlx @playwright/mcp@latest`
- スコープ: プロジェクト
- 機能: Webページのナビゲーション、フォーム入力、クリック、スナップショット取得
- 前提条件: なし（初回実行時にChromiumが自動インストール）
- 用途: UI動作確認、デバッグ、E2Eテスト作成支援

### GitHub MCP Server

GitHub APIへのアクセスを提供します。

- URL: `https://api.githubcopilot.com/mcp/`
- トランスポート: HTTP（リモートサーバー）
- スコープ: プロジェクト
- 機能: リポジトリ管理、Issue/PR操作、GitHub Actions監視、コードセキュリティ分析
- 認証: `gh auth token` のOAuthトークンを `GH_MCP_TOKEN` 環境変数経由で Bearer ヘッダーに設定
- 前提条件: `gh auth login` 済みの GitHub アカウント、`GH_MCP_TOKEN` 環境変数
- 参考: <https://github.com/github/github-mcp-server>
- 備考: `gh` CLIと機能が重複するが、MCPツールとしてLLMが直接利用できる利点がある

### Human-In-the-Loop Discord MCP Server

Discord経由で人間とのやり取りを提供します。

- コマンド: `/Users/rysk/.cargo/bin/human-in-the-loop`
- スコープ: プロジェクト
- 機能: Claude CodeからDiscord経由で質問・回答のやり取りが可能
- **注意**: 現在Claude CodeではMCPプロトコルバージョンの互換性問題により利用不可（Claude Desktopでは動作確認済み）

## Discord Bot設定（Human-In-the-Loop MCP用）

### MCPサーバーのインストール

```bash
# Rustがインストールされていることを確認
mise exec -- rustc --version

# Discord MCPサーバーをインストール
mise exec -- cargo install --git https://github.com/KOBA789/human-in-the-loop.git --config net.git-fetch-with-cli=true
```

### Discord Botの設定

1. [Discord Developer Portal](https://discord.com/developers/applications)でアプリケーション作成

2. Botセクションでボットを作成し、トークンを取得

3. Bot権限を設定：
   - Send Messages（メッセージ送信）
   - Create Public Threads（パブリックスレッド作成）
   - Read Message History（メッセージ履歴読取）

4. BotをDiscordサーバーに招待：
   - OAuth2 → URL Generatorに移動
   - Scopesで「bot」を選択
   - Bot Permissionsで以下を選択：
     - Send Messages
     - Create Public Threads
     - Send Messages in Threads
     - Read Message History
   - 生成されたURLをブラウザで開き、Botを対象サーバーに招待

5. Discord設定：
   - ユーザー設定 → 詳細設定 → 開発者モードを有効化
   - 対象チャンネルを右クリック → IDをコピー
   - 自分のユーザー名を右クリック → IDをコピー

6. 環境変数設定：

   ```bash
   export DISCORD_TOKEN="your_bot_token_here"
   export DISCORD_CHANNEL_ID="your_channel_id_here"
   export DISCORD_USER_ID="your_user_id_here"
   ```

7. 使用方法：
   Claude Codeで `@human-in-the-loop` を使って質問すると、Discordにスレッドが作成されます

## MCPサーバー設定ファイル

MCPサーバーの設定は以下のファイルに保存されます。

- プロジェクトスコープ: `.mcp.json` （このリポジトリ内）
- ユーザースコープ: `~/.claude.json` （`mcpServers` セクション）

現在のプロジェクト設定（`.mcp.json`）

```json
{
  "mcpServers": {
    "aws-docs": {
      "type": "stdio",
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    },
    "aws-api": {
      "type": "stdio",
      "command": "uvx",
      "args": ["awslabs.aws-api-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR",
        "READ_OPERATIONS_ONLY": "true"
      }
    },
    "playwright": {
      "type": "stdio",
      "command": "pnpm",
      "args": ["dlx", "@playwright/mcp@latest"],
      "env": {}
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${GH_MCP_TOKEN}"
      }
    }
  }
}
```

Human-In-the-Loop Discord MCPサーバーはローカル設定で管理されており、以下の環境変数が必要です。

- `DISCORD_TOKEN`: Discord Botトークン
- `DISCORD_CHANNEL_ID`: 対象のDiscordチャンネルID
- `DISCORD_USER_ID`: 対象のDiscordユーザーID

## Claude Desktop設定

Claude DesktopでMCPサーバーを利用する場合は、以下の設定ファイルを編集します。

- 設定ファイル: `~/Library/Application Support/Claude/claude_desktop_config.json`
- 形式: `mcpServers`セクションにサーバー設定を追加

Claude Desktopを再起動すると、設定したMCPサーバーが利用可能になります。

## MCP設定の管理コマンド（Claude Code）

```bash
# MCP サーバーの一覧表示
claude mcp list

# MCP サーバーの詳細確認
claude mcp get <server-name>

# MCP サーバーの追加（例）
claude mcp add <name> uvx <package-name> -s user -e ENV_VAR=value

# MCP サーバーの削除
claude mcp remove <name> -s user
```

注意事項:

- `~/.claude.json` はClaude Code内部で管理されるファイルのため、シンボリックリンクでの管理は推奨されません
- プロジェクト固有のMCPサーバーは、プロジェクトルートの `.mcp.json` ファイルで設定可能
- Claude Desktopの設定は別途 `claude_desktop_config.json` で管理されます
