#!/usr/bin/env bash
# Shell functions loaded by mise

# Run Lambda build in Docker environment
# Enables SSH authentication in Docker while keeping 1Password SSH agent active
build_lambda() {
    local ssh_config=~/.ssh/config
    local docker_config=~/.ssh/config_docker

    # Pre-flight checks
    if [[ ! -f "$ssh_config" ]]; then
        echo "Error: $ssh_config not found" >&2
        return 1
    fi

    if [[ ! -f "$docker_config" ]]; then
        echo "Error: $docker_config not found" >&2
        echo "Please generate the config file following the setup instructions" >&2
        return 1
    fi

    local backup=~/.ssh/config.backup.$$

    # Create backup
    if ! cp "$ssh_config" "$backup"; then
        echo "Error: Failed to backup SSH config" >&2
        return 1
    fi

    # Setup cleanup handler (restores config even on error)
    trap "mv '$backup' '$ssh_config' 2>/dev/null || true" EXIT

    # Switch to Docker SSH config
    if ! cp "$docker_config" "$ssh_config"; then
        echo "Error: Failed to switch to Docker SSH config" >&2
        mv "$backup" "$ssh_config"
        return 1
    fi

    # Execute build command
    "$@"
    local exit_code=$?

    # Explicit restoration
    trap - EXIT
    mv "$backup" "$ssh_config"

    return $exit_code
}

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
