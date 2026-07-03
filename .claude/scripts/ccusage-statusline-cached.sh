#!/usr/bin/env bash
# Cached wrapper around `ccusage statusline` for the Claude Code statusLine.
# The statusline command runs on every assistant message / tool call
# (debounced 300ms), and each run pays the mise-shim -> bun -> JSONL-parse
# startup chain. Cache the rendered line per session with a short TTL and
# refresh in the background (stale-while-revalidate) so most invocations
# return instantly without spawning ccusage.
#
# settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "bash /Users/rysk/.claude/scripts/ccusage-statusline-cached.sh"
#   }
set -euo pipefail

ttl_seconds=3
# A cold ccusage run takes ~10s (full JSONL parse), so anything shorter
# would reclaim the lock of a refresh that is still legitimately running
lock_stale_seconds=30

# stdin can only be read once; keep it to forward to ccusage later
input="$(cat)"

# Pure-bash extraction: jq also resolves through a mise shim, so calling it
# on the fast path would reintroduce the per-refresh spawn cost this cache
# exists to avoid
session_id=""
if [[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    session_id="${BASH_REMATCH[1]}"
fi
session_id="${session_id//[^A-Za-z0-9_-]/}"    # used as a filename
[[ -n "$session_id" ]] || session_id="default"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ccusage-statusline"
cache_file="$cache_dir/$session_id"
lock_dir="$cache_dir/$session_id.lock"

mkdir -p "$cache_dir"

# macOS (stat -f) with a Linux (stat -c) fallback
mtime_of() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

refresh_cache() {
    # Reclaim a lock left behind by a killed refresh; without this the
    # cache would never update again once a background job dies mid-run
    if [[ -d "$lock_dir" ]] && (( $(date +%s) - $(mtime_of "$lock_dir") > lock_stale_seconds )); then
        rmdir "$lock_dir" 2>/dev/null || true
    fi

    # mkdir is atomic, so it doubles as a lock against refresh pileup
    if ! mkdir "$lock_dir" 2>/dev/null; then
        return 0
    fi

    local tmp="$cache_file.tmp.$$"
    if command -v ccusage &>/dev/null \
        && printf '%s' "$input" | ccusage statusline >"$tmp" 2>/dev/null \
        && [[ -s "$tmp" ]]; then
        # Atomic replace so a concurrent reader never sees a partial line
        mv -f "$tmp" "$cache_file"
    else
        # ccusage missing or failed. `touch` bumps the cache mtime so the
        # TTL throttles retries even while failing, and creates an empty
        # file when none exists so the first-run wait loop terminates
        # instead of polling the full 12s. It keeps existing content, so a
        # good stale line survives a transient failure (stale-while-
        # revalidate); without the mtime bump, a persistent failure would
        # respawn a background refresh on every statusline call
        rm -f "$tmp"
        touch "$cache_file"
    fi

    # Release explicitly: EXIT traps never fire inside the `( ... & )`
    # background job, so a trap-based release would leak the lock every
    # refresh. A refresh killed before reaching this line is reclaimed by
    # the staleness check above
    rmdir "$lock_dir" 2>/dev/null || true

    # Opportunistic cleanup of dead-session caches; slow path only.
    # -mindepth 1 protects the cache dir itself; dropping -type f is what
    # lets orphaned .lock dirs from killed refreshes be reaped alongside
    # stale cache and .tmp files
    find "$cache_dir" -mindepth 1 -mtime +1 -delete 2>/dev/null || true
}

cache_is_fresh() {
    [[ -f "$cache_file" ]] || return 1
    (( $(date +%s) - $(mtime_of "$cache_file") < ttl_seconds ))
}

# Launch a refresh that outlives this script. Claude Code kills the whole
# statusline process group when a newer refresh supersedes it, which in a
# busy session happens well before the ~10s ccusage run finishes; `set -m`
# puts the job in its own process group so it survives that kill
refresh_cache_detached() {
    ( set -m; refresh_cache >/dev/null 2>&1 & ) </dev/null
}

if cache_is_fresh; then
    # Guard the cat: a concurrent refresh's `find -mtime +1 -delete` could
    # remove the file between the freshness check and here, and a bare cat
    # would abort under `set -e`
    cat "$cache_file" 2>/dev/null || true
elif [[ -f "$cache_file" ]]; then
    # Stale: return the old line immediately and refresh in the background
    cat "$cache_file" 2>/dev/null || true
    refresh_cache_detached
else
    # First call of a session: refresh in a kill-safe background job and
    # wait for the cache. If the harness kills this wrapper mid-wait, the
    # refresh keeps running and the next invocation serves the result
    refresh_cache_detached
    for _ in {1..60}; do
        [[ -f "$cache_file" ]] && break
        sleep 0.2
    done
    cat "$cache_file" 2>/dev/null || true
fi
exit 0
