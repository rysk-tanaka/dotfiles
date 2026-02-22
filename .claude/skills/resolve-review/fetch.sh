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
        pageInfo { hasNextPage }
        nodes {
          id
          isResolved
          isOutdated
          comments(first: 50) {
            pageInfo { hasNextPage }
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
      comments(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id
          body
          author { login }
          createdAt
          isMinimized
          url
        }
      }
    }
  }
}
'

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

RESPONSE=$(gh api graphql \
    -f query="$QUERY" \
    -f owner="$OWNER" \
    -f repo="$REPO" \
    -F number="$PR_NUMBER")

echo "$RESPONSE" > "$WORK_DIR/response"

# --- Pagination warnings ---

jq -e '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' "$WORK_DIR/response" > /dev/null 2>&1 \
    && echo "Warning: review threads exceeded 100, some threads may be missing." >&2

jq -e '[.data.repository.pullRequest.reviewThreads.nodes[].comments.pageInfo.hasNextPage] | any' "$WORK_DIR/response" > /dev/null 2>&1 \
    && echo "Warning: some threads exceeded 50 comments, replies may be missing." >&2

jq -e '.data.repository.pullRequest.comments.pageInfo.hasNextPage' "$WORK_DIR/response" > /dev/null 2>&1 \
    && echo "Warning: PR comments exceeded 100, some comments may be missing." >&2

# --- Bot authors (keep only latest comment per author) ---

BOT_AUTHORS='["claude"]'

# --- Transform to normalized JSON ---

jq -n \
    --argjson number "$PR_NUMBER" \
    --argjson bot_authors "$BOT_AUTHORS" \
    --rawfile response "$WORK_DIR/response" \
    '
    ($response | fromjson) as $data |
    $data.data.repository.pullRequest as $pr |

    # Build all non-minimized comments
    [
        $pr.comments.nodes[] |
        select(.isMinimized | not) |
        {
            id: .id,
            body: .body,
            author: (.author.login // "ghost"),
            created_at: .createdAt,
            url: .url
        }
    ] as $all_comments |

    # Split into human and bot comments
    [$all_comments[] | select(.author as $a | $bot_authors | index($a) | not)] as $human |
    [$all_comments[] | select(.author as $a | $bot_authors | index($a))] as $bot |

    # Keep only latest comment per bot author
    ([$bot | group_by(.author)[] | sort_by(.created_at) | last]) as $bot_latest |

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
        ],
        comments: ($human + $bot_latest | sort_by(.created_at)),
        bot_comments_omitted: (($bot | length) - ($bot_latest | length)),
        bot_comments_to_minimize: (($bot | map(.id)) - ($bot_latest | map(.id)))
    }
    '
