#!/usr/bin/env bash
# Collect PR data: validate branch/remote sync and gather diff, log, stat, template
set -euo pipefail

BASE_BRANCH="${1:?Usage: collect.sh <base-branch>}"

# --- Validation ---

CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "Error: detached HEAD state. Please checkout a branch first." >&2
    exit 1
fi

if [[ "$CURRENT_BRANCH" == "$BASE_BRANCH" ]]; then
    echo "Error: current branch ($CURRENT_BRANCH) is the same as base branch ($BASE_BRANCH)." >&2
    exit 1
fi

LOCAL_HASH=$(git rev-parse HEAD)
REMOTE_INFO=$(git ls-remote origin "$CURRENT_BRANCH" 2>/dev/null || true)

if [[ -z "$REMOTE_INFO" ]]; then
    echo "Error: remote branch 'origin/$CURRENT_BRANCH' does not exist. Run 'git push -u origin $CURRENT_BRANCH' first." >&2
    exit 1
fi

REMOTE_HASH=$(echo "$REMOTE_INFO" | awk '{print $1}')
if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
    echo "Error: local and remote are out of sync. Run 'git push' first." >&2
    echo "  Local:  $LOCAL_HASH" >&2
    echo "  Remote: $REMOTE_HASH" >&2
    exit 1
fi

# --- Data collection ---

STAT=$(git diff "${BASE_BRANCH}...HEAD" --stat)
LOG=$(git log "${BASE_BRANCH}..HEAD" --oneline)
DIFF=$(git diff "${BASE_BRANCH}...HEAD" -- . ':!*lock.json' ':!*.lock' ':!*lock.yaml' ':!*lock.toml')

TEMPLATE=""
TEMPLATE_PATHS=(
    ".github/workflows/pull_request_template.md" # intentional: setup-links symlinks here
    ".github/pull_request_template.md"
)
for tmpl in "${TEMPLATE_PATHS[@]}"; do
    if [[ -f "$tmpl" ]]; then
        TEMPLATE=$(cat "$tmpl")
        break
    fi
done

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "$STAT" > "$TMPDIR/stat"
echo "$LOG" > "$TMPDIR/log"
echo "$DIFF" > "$TMPDIR/diff"
echo "$TEMPLATE" > "$TMPDIR/template"

jq -n \
    --arg current_branch "$CURRENT_BRANCH" \
    --arg base_branch "$BASE_BRANCH" \
    --rawfile stat "$TMPDIR/stat" \
    --rawfile log "$TMPDIR/log" \
    --rawfile diff "$TMPDIR/diff" \
    --rawfile template "$TMPDIR/template" \
    '{
        current_branch: $current_branch,
        base_branch: $base_branch,
        stat: $stat,
        log: $log,
        diff: $diff,
        template: $template
    }'
