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

if [[ -z "$RESULT" ]]; then
    # Fallback: output entire stderr for best-effort analysis
    cat "$WORK_DIR/stderr"
else
    printf '%s\n' "$RESULT"
fi
