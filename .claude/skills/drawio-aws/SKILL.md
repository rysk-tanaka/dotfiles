---
name: drawio-aws
description: draw.io で AWS アーキテクチャ図を作成（AWS 4 アイコン、カテゴリ別カラー指定付き）
allowed-tools: Bash, Write
---

# draw.io AWS Architecture Diagram Skill

draw.io スキルのラッパー。AWS アーキテクチャ図を作成する際の AWS 4 シェイプライブラリの使い方と注意点をまとめたもの。

基本的な draw.io の操作（XML 構造、エクスポート、CLI）は `/drawio` スキルに従う。このスキルは AWS 固有の知識を補完する。

## AWS 4 アイコンのスタイル

直接シェイプ（`shape=mxgraph.aws4.*`）を使用する。`fillColor` は必須 — 指定しないと CLI エクスポート時にアイコンが透過になる。

### ベーステンプレート

```xml
<mxCell id="example" parent="1"
  style="outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#XXXXXX;strokeColor=none;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=11;fontStyle=0;aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.SHAPE_NAME;labelBackgroundColor=#FFFFFF;"
  value="Label" vertex="1">
  <mxGeometry height="60" width="60" x="0" y="0" as="geometry" />
</mxCell>
```

### カテゴリ別 fillColor

| カテゴリ | fillColor | 主なシェイプ |
| --- | --- | --- |
| Compute | `#ED7100` | `lambda_function` |
| Database | `#C925D1` | `dynamodb`, `dynamodb_stream`, `rds`, `aurora` |
| Storage | `#3F8624` | `s3`, `s3_glacier`, `efs` |
| App Integration | `#E7157B` | `sns`, `sqs`, `eventbridge`, `step_functions` |
| Management | `#E7157B` | `parameter_store`, `cloudwatch`, `cloudformation` |
| Networking | `#8C4FFF` | `vpc`, `elb`, `route53`, `cloudfront`, `api_gateway` |
| Security | `#DD344C` | `iam`, `cognito`, `kms`, `waf` |
| General | `#232F3E` | `endpoint`, `client`, `user` |

### グループコンテナのスタイル

```xml
<!-- AWS Cloud -->
<mxCell style="...shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_aws_cloud_alt;stroke=#232F3E;fillColor=none;..." />

<!-- VPC -->
<mxCell style="...shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_vpc2;stroke=#8C4FFF;fillColor=none;..." />

<!-- Availability Zone -->
<mxCell style="...shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_availability_zone;stroke=#007CBC;fillColor=none;..." />

<!-- Corporate Data Center / External -->
<mxCell style="...shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_corporate_data_center;stroke=#147EBA;fillColor=none;..." />
```

## テキストサイズ

| 要素 | fontSize | 用途 |
| --- | --- | --- |
| アイコンラベル | 13 | メインフローおよび補助サービスのラベル |
| 補助アイコンラベル | 12 | DLQ 等の小型アイコン |
| 注釈テキスト | 12 | 補足説明、脚注 |
| セクションラベル | 14 | Data Layer 等のグループラベル（fontStyle=3: italic） |
| コンテナラベル | 14 | AWS Cloud, VPC 等（fontStyle=1: bold） |
| タイトル | 18 | 図全体のタイトル（fontStyle=1: bold） |
| 凡例テキスト | 13 | Legend のテキスト |

ベーステンプレートの `fontSize=11` はデフォルト値。ユーザーから指定がなければ上記を適用する。

## レイアウトガイドライン

- アイコンサイズ: メイン 60x60、補助（DLQ 等）48x48
- ノード間隔: 水平 160px 以上、垂直 120px 以上（ブランチ間 200px 推奨）
- 座標はグリッド 10px 単位に揃える
- メインフロー（左→右）は同じ Y 座標に配置

### ラベル配置

デフォルトはアイコン下（`verticalLabelPosition=bottom;verticalAlign=top;align=center`）。
メインフロー矢印と干渉する場合は右側ラベルに切り替える。

```xml
<!-- 右側ラベル（矢印との重なり回避用） -->
labelPosition=right;verticalLabelPosition=middle;verticalAlign=middle;align=left;spacingLeft=10;
```

使い分けの基準。

- 下ラベル: メインフロー上のアイコン（左右にスペースがある）
- 右ラベル: メインフロー経路の近くに配置される補助サービス（Parameter Store, CloudWatch 等）

同じ役割のサービス（監視系、設定系など）はラベル位置を統一する。

### 共有サービスの配置

複数ブランチから参照されるサービス（SSM, CloudWatch 等）は以下に注意する。

- メインフロー矢印と同じ Y 座標に置かない（矢印がアイコンを貫通する）
- ブランチ間の中央付近に配置し、右側ラベルを使用する
- メインフロー矢印の Y と 20px 以上の間隔を確保する

## エッジスタイル

```xml
<!-- メインフロー: 太い実線 -->
<mxCell style="html=1;strokeColor=#232F3E;strokeWidth=2;" edge="1" />

<!-- 補助接続: 細い破線 -->
<mxCell style="html=1;strokeColor=#999999;strokeWidth=1;dashed=1;" edge="1" />
```

### 接続ポイントの制御

`exitX/exitY/entryX/entryY`（0-1）と `exitPerimeter=0` で制御する。

メインフロー矢印と補助線が同じアイコンから出る場合、異なる exit ポイントを使い分ける。

```text
exitY=0.5（中央）→ メインフロー
exitY=0.75 / 0.25 → 補助線（SSM, CW 等への接続）
exitY=0 / 1（上端/下端）→ 補助線（データ層、DLQ への接続）
```

## 注意事項

- コンテナ間のエッジは `parent="1"` に設定する（コンテナの子にすると座標がずれる）
- `<mxGeometry relative="1" as="geometry" />` はすべてのエッジに必須
- XML 定義順が z-order になる（コンテナ → エッジ → アイコンの順で定義）
- `labelBackgroundColor=#FFFFFF` でラベルがエッジと重なっても読みやすくなる
