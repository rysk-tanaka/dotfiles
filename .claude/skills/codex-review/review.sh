#!/usr/bin/env bash
# Run codex review and extract the review result from stderr
set -euo pipefail

BASE_BRANCH="${1:-main}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# codex review outputs everything to stderr (stdout is empty)
if ! codex review --base "$BASE_BRANCH" >"$WORK_DIR/stdout" 2>"$WORK_DIR/stderr"; then
    cat "$WORK_DIR/stderr" >&2
    exit 1
fi

# Extract the "codex" section from role-tagged output
# Format: lines like "user", "thinking", "exec", "codex" act as section headers
RESULT=$(awk '
BEGIN { in_codex = 0 }
/^(user|thinking|exec|codex)$/ {
    in_codex = ($0 == "codex")
    next
}
in_codex { print }
' "$WORK_DIR/stderr")

# Extract session id from stderr for cache persistence
SESSION_ID=$(grep -oE 'session id: [0-9a-f-]+' "$WORK_DIR/stderr" | cut -d' ' -f3 || true)

CACHE_DIR="$HOME/.cache/claude-bg"
mkdir -p "$CACHE_DIR"
# Clean up cache files older than 7 days
find "$CACHE_DIR" -name 'codex-review-*.txt' -mtime +7 -delete 2>/dev/null || true

if [[ -z "$RESULT" ]]; then
    # Fallback: output entire stderr for best-effort analysis
    cat "$WORK_DIR/stderr"
    if [[ -n "$SESSION_ID" ]]; then
        cat "$WORK_DIR/stderr" > "$CACHE_DIR/codex-review-$SESSION_ID.txt"
    fi
else
    printf '%s\n' "$RESULT"
    if [[ -n "$SESSION_ID" ]]; then
        printf '%s\n' "$RESULT" > "$CACHE_DIR/codex-review-$SESSION_ID.txt"
    fi
fi
