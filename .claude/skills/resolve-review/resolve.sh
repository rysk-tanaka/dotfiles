#!/usr/bin/env bash
# Resolve PR review threads by node ID
# Usage: resolve.sh <node_id> [<node_id> ...]
set -euo pipefail

for id in "$@"; do
    echo "Resolving: $id" >&2
    # shellcheck disable=SC2016 # $id is a GraphQL variable, not a shell variable
    gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id="$id" \
        || echo "Warning: failed to resolve thread $id" >&2
done
