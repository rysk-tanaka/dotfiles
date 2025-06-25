# MCP（Model Context Protocol）設定

Claude CodeはMCPサーバーを使って外部ツールやサービスと連携できます。

## 利用可能なMCPサーバー

### AWS Documentation MCP Server

AWSドキュメントへのアクセスを提供します。

- コマンド: `uvx awslabs.aws-documentation-mcp-server@latest`
- スコープ: プロジェクト（このリポジトリでのみ利用可能）
- 機能: AWS認証不要でドキュメントの閲覧・検索が可能

### Human-In-the-Loop Discord MCP Server

Discord経由で人間とのやり取りを提供します。

- コマンド: `/Users/rysk/.cargo/bin/human-in-the-loop`
- スコープ: プロジェクト（このリポジトリでのみ利用可能）
- 機能: Claude CodeからDiscord経由で質問・回答のやり取りが可能

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

4. Discord設定：
   - ユーザー設定 → 詳細設定 → 開発者モードを有効化
   - 対象チャンネルを右クリック → IDをコピー
   - 自分のユーザー名を右クリック → IDをコピー

5. 環境変数設定：

   ```bash
   export DISCORD_TOKEN="your_bot_token_here"
   export DISCORD_CHANNEL_ID="your_channel_id_here"
   export DISCORD_USER_ID="your_user_id_here"
   ```

6. 使用方法：
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
    }
  }
}
```

Human-In-the-Loop Discord MCPサーバーはローカル設定で管理されており、以下の環境変数が必要です。

- `DISCORD_TOKEN`: Discord Botトークン
- `DISCORD_CHANNEL_ID`: 対象のDiscordチャンネルID
- `DISCORD_USER_ID`: 対象のDiscordユーザーID

## MCP設定の管理コマンド

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
