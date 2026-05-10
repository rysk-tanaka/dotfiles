#!/usr/bin/env bash
# Surface outdated plugin marketplaces on session start.
# anthropics/claude-code#41885: session-start auto-sync only does `git fetch`,
# and DISABLE_AUTOUPDATER=1 in this repo turns even that off, so installed
# plugins go stale silently. This hook compares HEAD to the locally-known
# upstream ref (no network in foreground) and fires a detached `git fetch` so
# the next session has fresh state. Result: at most a 1-session lag on detection,
# but zero startup latency.
# Skips non-git marketplaces (e.g. claude-plugins-official uses a GCS snapshot).
set -euo pipefail

MARKETPLACES_DIR="${HOME}/.claude/plugins/marketplaces"
[[ -d "$MARKETPLACES_DIR" ]] || exit 0

behind_lines=()

for mp in "$MARKETPLACES_DIR"/*/; do
    [[ -d "${mp}.git" ]] || continue

    git -C "$mp" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || continue

    behind=$(git -C "$mp" rev-list HEAD..'@{u}' --count 2>/dev/null || echo 0)
    if [[ "${behind:-0}" -gt 0 ]]; then
        name=$(basename "$mp")
        behind_lines+=("  - ${name} is ${behind} commits behind upstream")
    fi

    # Detached subshell so the hook returns immediately even if fetch is slow.
    ( git -C "$mp" fetch --quiet --no-tags >/dev/null 2>&1 & )
done

[[ ${#behind_lines[@]} -gt 0 ]] || exit 0

printf '[plugin-update] Outdated plugin marketplaces detected:\n'
for line in "${behind_lines[@]}"; do
    printf '%s\n' "$line"
done
printf '  Run: mise run upgrade-plugins\n'
