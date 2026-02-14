#!/usr/bin/env bash
# Collect branch context data for branch name suggestion
set -euo pipefail

BASE_BRANCH="${1:-main}"

# --- Data collection ---

CURRENT_BRANCH=$(git branch --show-current)
STATUS=$(git status --short)

# Check if base branch exists
COMMIT_LOG=""
if git rev-parse --verify "$BASE_BRANCH" &>/dev/null; then
    COMMIT_LOG=$(git log "${BASE_BRANCH}..HEAD" --oneline 2>/dev/null || true)
fi

REMOTE_BRANCHES=$(git branch -r --format='%(refname:short)' 2>/dev/null | head -30 || true)

# --- Output JSON ---

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Use printf '%s' to avoid implicit trailing newline on empty values
printf '%s' "$CURRENT_BRANCH" > "$WORK_DIR/current_branch"
printf '%s' "$STATUS" > "$WORK_DIR/status"
printf '%s' "$COMMIT_LOG" > "$WORK_DIR/commit_log"
printf '%s' "$REMOTE_BRANCHES" > "$WORK_DIR/remote_branches"

jq -n \
    --arg base_branch "$BASE_BRANCH" \
    --rawfile current_branch "$WORK_DIR/current_branch" \
    --rawfile status "$WORK_DIR/status" \
    --rawfile commit_log "$WORK_DIR/commit_log" \
    --rawfile remote_branches "$WORK_DIR/remote_branches" \
    '{
        base_branch: $base_branch,
        current_branch: $current_branch,
        status: $status,
        commit_log: $commit_log,
        remote_branches: $remote_branches
    }'
