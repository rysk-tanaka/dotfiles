#!/bin/bash
set -uo pipefail
# Attach to a tmux session for Zed editor terminal integration.
# Each Zed terminal tab claims a unique tmux window via lock files,
# preventing display sync and preserving scrollback across restarts.
T=$(command -v tmux) || { echo "tmux not found" >&2; exit 1; }
HASH=$(echo -n "$PWD" | md5 -q | head -c 8)
BASE="zed-$(basename "$PWD" | tr -dc 'a-zA-Z0-9_-')-${HASH}"
LOCKDIR="/tmp/tmux-zed-locks"
mkdir -p "$LOCKDIR"

# Create base session (detached) if it doesn't exist
if ! "$T" has-session -t "$BASE" 2>/dev/null; then
  "$T" new-session -d -s "$BASE"
fi

# Clean up orphaned grouped sessions (no attached clients)
"$T" list-sessions -F '#{session_name} #{session_group} #{session_attached}' 2>/dev/null | \
  while read -r name group attached; do
    if [ "$group" = "$BASE" ] && [ "$name" != "$BASE" ] && [ "$attached" = "0" ]; then
      "$T" kill-session -t "$name" 2>/dev/null || true
    fi
  done

# Clean up stale lock files (from dead processes)
# Note: exec preserves PID, so kill -0 correctly detects stale locks
for lockfile in "$LOCKDIR/${BASE}"-*; do
  [ -f "$lockfile" ] || continue
  pid=$(cat "$lockfile" 2>/dev/null)
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$lockfile"
  fi
done

# Claim an unclaimed window via lock file (atomic with noclobber)
# Session name is derived from window ID to avoid race conditions
for win_id in $("$T" list-windows -t "$BASE" -F '#{window_id}'); do
  lockfile="$LOCKDIR/${BASE}-${win_id}"
  if (set -C; echo $$ > "$lockfile") 2>/dev/null; then
    suffix=${win_id#@}
    exec "$T" new-session -t "$BASE" -s "${BASE}-${suffix}" \; select-window -t "$win_id"
  fi
done

# All windows claimed: create and claim a new one
new_win_id=$("$T" new-window -t "$BASE" -P -F '#{window_id}')
lockfile="$LOCKDIR/${BASE}-${new_win_id}"
(set -C; echo $$ > "$lockfile") 2>/dev/null || true
suffix=${new_win_id#@}
exec "$T" new-session -t "$BASE" -s "${BASE}-${suffix}" \; select-window -t "$new_win_id"
