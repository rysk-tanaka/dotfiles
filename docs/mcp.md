# MCP（Model Context Protocol）設定

Claude CodeはMCPサーバーを使って外部ツールやサービスと連携できます。

## 利用可能なMCPサーバー

### AWS Documentation MCP Server

AWSドキュメントへのアクセスを提供します。

- コマンド: `uvx awslabs.aws-documentation-mcp-server@latest`
- スコープ: プロジェクト
- 機能: AWS認証不要でドキュメントの閲覧・検索が可能

### AWS MCP Server

AWSがホストするマネージドリモートMCPサーバーです。開発終了となったOSS版 `awslabs.aws-api-mcp-server` の後継として移行しました。

- コマンド: `uvx mcp-proxy-for-aws@1.6.4 https://aws-mcp.us-east-1.api.aws/mcp --read-only`
- スコープ: プロジェクト
- 機能: 15,000以上のAWS APIの実行、ドキュメント取得、サンドボックスでのスクリプト実行
- 構成: ローカルには軽量プロキシ `mcp-proxy-for-aws` のみ配置し、リクエストをSigV4で署名してAWS側で実行
- 設定: `--read-only` フラグで書き込み権限が必要なツールを無効化。IAMポリシーの `aws:ViaAWSMCPService` コンテキストキーでも制御可能
- 前提条件: AWS CLI/SDKの認証チェーンに従ったAWS認証情報の設定
- バージョン: 移行ガイドの推奨に従い、サプライチェーン対策として `@latest` ではなく特定バージョンに固定。更新は Renovate の custom manager が `.mcp.json` とこのドキュメントを追従
- 運用方針: マルチアカウント環境で IAM ポリシー整備が現実的でないため `--read-only` を維持し、MCP はドキュメント検索等の知識系ツールに限定。読み取りを含む AWS 操作は AWS CLI + プロファイル切替で行う
- 参考: <https://github.com/awslabs/mcp/blob/main/src/aws-api-mcp-server/MIGRATION.md>

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

### Draw.io MCP Server

draw.io図表の作成・編集機能を提供します。

- コマンド: `pnpm dlx @drawio/mcp@1.1.6`
- スコープ: プロジェクト
- 機能: draw.ioエディタでXML/CSV/Mermaid形式の図表を生成・表示
- 前提条件: Node.js >= 18、pnpm
- 参考: <https://github.com/jgraph/drawio-mcp>
- ツール
  - `open_drawio_xml` - draw.io XML形式で図表を開く
  - `open_drawio_csv` - CSVデータを図表に変換（組織図、フローチャート等）
  - `open_drawio_mermaid` - Mermaid.js記法を編集可能な図表に変換

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
    "aws-mcp": {
      "type": "stdio",
      "command": "uvx",
      "args": [
        "mcp-proxy-for-aws@1.6.4",
        "https://aws-mcp.us-east-1.api.aws/mcp",
        "--read-only"
      ]
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
    },
    "drawio": {
      "type": "stdio",
      "command": "pnpm",
      "args": ["dlx", "@drawio/mcp@1.1.6"],
      "env": {}
    }
  }
}
```

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
