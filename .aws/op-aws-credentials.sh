#!/bin/bash
# AWS credential_process ヘルパー: 認証情報を 1Password から取得する。
#
# 使い方: op-aws-credentials.sh <item名> <vault名>
#   ~/.aws/config 例:
#     [profile <profile名>]
#     credential_process = /path/to/op-aws-credentials.sh "<item名>" "<vault名>"
#
# 1Password アイテムには "access key id" / "secret access key" フィールドが必要。
#
# 公式の 1Password shell plugin (`op plugin init aws`) を使わない理由:
# plugin は `aws` コマンドをシェルの alias でラップする仕組みのため、対話的な `aws` 実行にしか効かない。
# Terraform や SDK は alias を経由せず認証情報チェーンを直接解決するので、plugin では認証情報が渡らない。
# credential_process なら AWS の config 側で解決されるため、
# aws CLI / Terraform / SDK のすべてが一貫して 1Password から取得できる。
set -eu

if [ $# -ne 2 ]; then
  echo "Usage: $(basename "$0") <item-name> <vault-name>" >&2
  exit 1
fi

item_name=$1
vault_name=$2

op item get "$item_name" --vault "$vault_name" --format json \
  | jq '{Version: 1,
         AccessKeyId:     (.fields[] | select(.label=="access key id")     | .value),
         SecretAccessKey: (.fields[] | select(.label=="secret access key") | .value)}'
