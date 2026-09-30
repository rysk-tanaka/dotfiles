# MCP（Model Context Protocol）設定

Claude CodeはMCPサーバーを使って外部ツールやサービスと連携できます。

## 利用可能なMCPサーバー

### AWS Documentation MCP Server

AWSドキュメントへのアクセスを提供します。

- コマンド: `uvx awslabs.aws-documentation-mcp-server@1.2.1`
- スコープ: プロジェクト
- 機能: AWS認証不要でドキュメントの閲覧・検索が可能

### AWS Knowledge MCP Server

AWSがホストするマネージドリモートMCPサーバーです。認証不要でAWSの公式情報を検索・取得できます。

- URL: `https://knowledge-mcp.global.api.aws`
- トランスポート: HTTP（リモートサーバー）
- スコープ: プロジェクト
- 機能: AWSドキュメント・What's New・ブログ・Well-Architected等の横断検索と取得、リージョン別の提供状況確認、AWS Agent Skillsの取得
- 前提条件: なし。AWSアカウントや認証情報は不要だが、レート制限がある
- AWS Documentation MCP Serverとの使い分け: 検索・取得は重複するが、ドキュメント以外の情報源やリージョン情報は本サーバー、節単位の取得（`read_sections`）や大きな表の行検索（`search_table`）はAWS Documentation MCP Serverを使う
- 運用方針: MCPは知識系ツールに限定し、読み取りを含むAWS操作はAWS CLI + プロファイル切替で行う
- 選定理由: 以前は `mcp-proxy-for-aws` 経由のAWS MCP Serverを `--read-only` で使っていたが、SigV4署名のため起動のたびに認証情報を解決し、`credential_process` 経由の1Passwordアンロックを要求していた。知識系ツールに限定する運用では認証が不要なため置き換えた。API実行が必要になった場合はAWS MCP Serverを再導入する
- 参考: <https://awslabs.github.io/mcp/servers/aws-knowledge-mcp-server>

### Playwright MCP Server

ブラウザ自動化機能を提供します。

- コマンド: `pnpm dlx @playwright/mcp@latest`
- スコープ: プロジェクト
- 機能: Webページのナビゲーション、フォーム入力、クリック、スナップショット取得
- 前提条件: なし。初回実行時にChromiumが自動インストールされる
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
  - `open_drawio_csv` - CSVデータを組織図やフローチャート等の図表に変換
  - `open_drawio_mermaid` - Mermaid.js記法を編集可能な図表に変換

## MCPサーバー設定ファイル

MCPサーバーの設定は以下のファイルに保存されます。

- プロジェクトスコープ: このリポジトリ内の `.mcp.json`
- ユーザースコープ: `~/.claude.json` の `mcpServers` セクション

プロジェクト設定 `.mcp.json` の現在の内容

```json
{
  "mcpServers": {
    "aws-docs": {
      "type": "stdio",
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@1.2.1"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    },
    "aws-knowledge": {
      "type": "http",
      "url": "https://knowledge-mcp.global.api.aws"
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

Claude Desktopを再起動すると、設定したMCPサーバーを利用できます。

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
