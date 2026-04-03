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
            if ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "Error: --lines must be a positive integer" >&2; exit 1
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

# --- Normalize refs ---
# cmux accepts "surface:N" but not bare "N" for --surface.
# cmux accepts both "N" and "workspace:N" for --workspace.

if [[ -n "$SURFACE" && "$SURFACE" =~ ^[0-9]+$ ]]; then
    SURFACE="surface:${SURFACE}"
fi

if [[ -n "$WORKSPACE" && "$WORKSPACE" =~ ^[0-9]+$ ]]; then
    WORKSPACE="workspace:${WORKSPACE}"
fi

# --- List mode ---

if [[ "$LIST_MODE" == true ]]; then
    if [[ -n "$WORKSPACE" ]]; then
        cmux list-pane-surfaces --workspace "$WORKSPACE"
    else
        ws_output=$(cmux list-workspaces)
        echo "$ws_output"
        echo ""
        while IFS= read -r line; do
            ws_ref=$(echo "$line" | grep -oE 'workspace:[0-9]+' || true)
            [[ -z "$ws_ref" ]] && continue
            echo "=== $ws_ref ==="
            cmux list-pane-surfaces --workspace "$ws_ref"
            echo ""
        done <<< "$ws_output"
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

cmd=(cmux read-screen --surface "$SURFACE" --lines "$LINES")
if [[ -n "$WORKSPACE" ]]; then
    cmd+=(--workspace "$WORKSPACE")
fi

"${cmd[@]}"
