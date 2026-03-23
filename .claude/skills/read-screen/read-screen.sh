#!/usr/bin/env bash
# Read terminal output from a cmux surface with bounded line count
set -euo pipefail

# --- Defaults ---

SURFACE=""
WORKSPACE=""
LINES=100
LIST_MODE=false

# --- Argument parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)     LIST_MODE=true; shift ;;
        --workspace)
            if [[ $# -lt 2 ]]; then
                echo "Error: --workspace requires a value" >&2; exit 1
            fi
            WORKSPACE="$2"; shift 2 ;;
        --lines)
            if [[ $# -lt 2 ]]; then
                echo "Error: --lines requires a value" >&2; exit 1
            fi
            LINES="$2"; shift 2 ;;
        -*)      echo "Error: unknown flag: $1" >&2; exit 1 ;;
        *)
            if [[ -z "$SURFACE" ]]; then
                SURFACE="$1"
            else
                echo "Error: unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# --- Build workspace args ---

ws_args=()
if [[ -n "$WORKSPACE" ]]; then
    ws_args+=(--workspace "$WORKSPACE")
fi

# --- List mode ---

if [[ "$LIST_MODE" == true ]]; then
    cmux list-workspaces
    echo ""
    if [[ -n "$WORKSPACE" ]]; then
        cmux list-pane-surfaces "${ws_args[@]}"
    else
        # Show surfaces for all workspaces
        while IFS= read -r line; do
            ws_ref=$(echo "$line" | grep -oE 'workspace:[0-9]+')
            [[ -z "$ws_ref" ]] && continue
            echo "=== $ws_ref ==="
            cmux list-pane-surfaces --workspace "$ws_ref"
            echo ""
        done < <(cmux list-workspaces)
    fi
    exit 0
fi

# --- Read mode ---

if [[ -z "$SURFACE" ]]; then
    echo "Error: surface id or ref is required" >&2
    echo "Usage: read-screen.sh <surface-id|ref> [--workspace <ref>] [--lines <n>]" >&2
    echo "       read-screen.sh --list [--workspace <ref>]" >&2
    exit 1
fi

cmux read-screen "${ws_args[@]}" --surface "$SURFACE" --lines "$LINES"
