#!/usr/bin/env bash
# Collect staged changes data for commit message generation
set -euo pipefail

# --- Validation ---

if git diff --cached --quiet 2>/dev/null; then
    echo "Error: No staged changes found. Run 'git add' first." >&2
    exit 1
fi

# --- Data collection ---

STAGED_FILES=$(git diff --cached --name-only)
LOG=$(git log --oneline -10 2>/dev/null || true)
STAT=$(git diff --cached --stat)

# Identify large files (>500 changed lines) to exclude from detailed diff
LARGE_FILE_EXCLUDES=()
EXCLUDED_LARGE_FILES=""
while IFS=$'\t' read -r added removed file; do
    [[ "$added" == "-" || "$removed" == "-" ]] && continue  # binary
    total=$((added + removed))
    if [[ $total -gt 500 ]]; then
        LARGE_FILE_EXCLUDES+=(":!$file")
        EXCLUDED_LARGE_FILES+="$file"$'\n'
    fi
done < <(git diff --cached --numstat)

PATHSPEC=("." ":!*lock*" ${LARGE_FILE_EXCLUDES[@]+"${LARGE_FILE_EXCLUDES[@]}"})
DIFF=$(git diff --cached -- "${PATHSPEC[@]}")

# --- Output JSON ---

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "$STAGED_FILES" > "$WORK_DIR/staged_files"
echo "$LOG" > "$WORK_DIR/log"
echo "$STAT" > "$WORK_DIR/stat"
echo "$DIFF" > "$WORK_DIR/diff"
echo "$EXCLUDED_LARGE_FILES" > "$WORK_DIR/excluded_large_files"

jq -n \
    --rawfile staged_files "$WORK_DIR/staged_files" \
    --rawfile log "$WORK_DIR/log" \
    --rawfile stat "$WORK_DIR/stat" \
    --rawfile diff "$WORK_DIR/diff" \
    --rawfile excluded_large_files "$WORK_DIR/excluded_large_files" \
    '{
        staged_files: $staged_files,
        log: $log,
        stat: $stat,
        diff: $diff,
        excluded_large_files: $excluded_large_files
    }'
