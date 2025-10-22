#!/usr/bin/env bash
# Shell functions loaded by mise

# markdownlint-cli2 wrapper that runs from git root
mdlint() {
  # Check if markdownlint-cli2 is available
  if ! command -v markdownlint-cli2 &>/dev/null; then
    echo "Error: markdownlint-cli2 is not installed" >&2
    echo "Install with: mise install" >&2
    return 1
  fi

  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)

  if [ -n "$git_root" ]; then
    local current_dir=$(pwd)

    # Convert arguments to paths relative to git root
    local args=()
    for arg in "$@"; do
      # Skip flags (starting with -)
      if [[ "$arg" == -* ]]; then
        args+=("$arg")
      else
        # If argument is a file/directory path
        if [ -e "$arg" ]; then
          # Get absolute path
          local abs_path
          if [[ "$arg" = /* ]]; then
            # Already absolute
            abs_path="$arg"
          else
            # Make absolute
            abs_path="$current_dir/$arg"
          fi

          # Remove git root prefix to get relative path
          local rel_path="${abs_path#$git_root/}"
          # If path didn't change, it means it's not under git root
          if [ "$rel_path" = "$abs_path" ]; then
            rel_path="$arg"
          fi

          args+=("$rel_path")
        else
          # Pass through glob patterns and other arguments
          args+=("$arg")
        fi
      fi
    done

    (cd "$git_root" && markdownlint-cli2 "${args[@]}")
  else
    # Not in a git repository, run normally
    markdownlint-cli2 "$@"
  fi
}
