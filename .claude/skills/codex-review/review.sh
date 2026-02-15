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
else
    printf '%s\n' "$RESULT"
fi

# Extract usage from session JSONL
USAGE=""
if [[ -n "$SESSION_ID" ]]; then
    TODAY=$(date -u +%Y/%m/%d)
    SESSION_FILE=$(find "$HOME/.codex/sessions" -name "*${SESSION_ID}.jsonl" -path "*${TODAY}*" 2>/dev/null | head -1 || true)
    # Fallback: search without date constraint
    if [[ -z "$SESSION_FILE" ]]; then
        SESSION_FILE=$(find "$HOME/.codex/sessions" -name "*${SESSION_ID}.jsonl" 2>/dev/null | head -1 || true)
    fi
    if [[ -n "$SESSION_FILE" ]]; then
        USAGE=$(grep '"token_count"' "$SESSION_FILE" | tail -1 | jq -c '{
            total_tokens: .payload.info.total_token_usage.total_tokens,
            input_tokens: .payload.info.total_token_usage.input_tokens,
            cached_tokens: .payload.info.total_token_usage.cached_input_tokens,
            output_tokens: .payload.info.total_token_usage.output_tokens,
            reasoning_tokens: .payload.info.total_token_usage.reasoning_output_tokens,
            rate_limit_5h: .payload.info.rate_limits.primary.used_percent,
            rate_limit_weekly: .payload.info.rate_limits.secondary.used_percent
        }' 2>/dev/null || true)
        if [[ -n "$USAGE" ]]; then
            printf '\n---USAGE---\n%s\n' "$USAGE"
        fi
    fi
fi

# Cache output for session loss recovery
if [[ -n "$SESSION_ID" ]]; then
    OUTPUT=$(if [[ -z "$RESULT" ]]; then cat "$WORK_DIR/stderr"; else printf '%s\n' "$RESULT"; fi)
    if [[ -n "$USAGE" ]]; then
        printf '%s\n\n---USAGE---\n%s\n' "$OUTPUT" "$USAGE" > "$CACHE_DIR/codex-review-$SESSION_ID.txt"
    else
        printf '%s\n' "$OUTPUT" > "$CACHE_DIR/codex-review-$SESSION_ID.txt"
    fi
fi
