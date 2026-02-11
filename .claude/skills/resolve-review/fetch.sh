#!/usr/bin/env bash
# Fetch PR review threads with resolved status via GraphQL API
set -euo pipefail

# --- PR number ---

if [[ $# -ge 1 && "$1" =~ ^[0-9]+$ ]]; then
    PR_NUMBER="$1"
else
    PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || true)
    if [[ -z "$PR_NUMBER" ]]; then
        echo "Error: no PR found for current branch. Specify a PR number as argument." >&2
        exit 1
    fi
fi

# --- owner/repo ---

OWNER_REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
OWNER="${OWNER_REPO%%/*}"
REPO="${OWNER_REPO##*/}"

# --- GraphQL query ---

QUERY='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      title
      url
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          comments(first: 50) {
            nodes {
              body
              author { login }
              createdAt
              path
              line
              diffHunk
            }
          }
        }
      }
    }
  }
}
'

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

RESPONSE=$(gh api graphql \
    -f query="$QUERY" \
    -f owner="$OWNER" \
    -f repo="$REPO" \
    -F number="$PR_NUMBER")

echo "$RESPONSE" > "$TMPDIR/response"

# --- Transform to normalized JSON ---

jq -n \
    --argjson number "$PR_NUMBER" \
    --rawfile response "$TMPDIR/response" \
    '
    ($response | fromjson) as $data |
    $data.data.repository.pullRequest as $pr |
    {
        pr_number: $number,
        title: $pr.title,
        url: $pr.url,
        review_threads: [
            $pr.reviewThreads.nodes[] | {
                id: .id,
                is_resolved: .isResolved,
                is_outdated: .isOutdated,
                comments: [
                    .comments.nodes[] | {
                        body: .body,
                        author: (.author.login // "ghost"),
                        created_at: .createdAt,
                        path: .path,
                        line: .line,
                        diff_hunk: .diffHunk
                    }
                ]
            }
        ]
    }
    '
