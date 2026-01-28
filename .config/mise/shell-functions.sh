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
# Only processes .md files, skipping non-markdown files
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
        # If argument is a directory
        if [ -d "$arg" ]; then
          # Directory: convert to glob pattern for .md files only
          local abs_path
          if [[ "$arg" = /* ]]; then
            abs_path="$arg"
          else
            abs_path="$current_dir/$arg"
          fi

          local rel_path="${abs_path#$git_root/}"
          if [ "$rel_path" = "$abs_path" ]; then
            rel_path="$arg"
          fi

          # Append /**/*.md to only target markdown files
          args+=("${rel_path%/}/**/*.md")
        else
          # Pass through files, glob patterns and other arguments
          if [ -f "$arg" ]; then
            # File: convert to relative path
            local abs_path
            if [[ "$arg" = /* ]]; then
              abs_path="$arg"
            else
              abs_path="$current_dir/$arg"
            fi

            local rel_path="${abs_path#$git_root/}"
            if [ "$rel_path" = "$abs_path" ]; then
              rel_path="$arg"
            fi

            args+=("$rel_path")
          else
            # Glob pattern or other argument
            args+=("$arg")
          fi
        fi
      fi
    done

    (cd "$git_root" && markdownlint-cli2 "${args[@]}")
  else
    # Not in a git repository, convert directories to glob patterns
    local args=()
    for arg in "$@"; do
      if [[ "$arg" == -* ]]; then
        args+=("$arg")
      elif [ -d "$arg" ]; then
        # Directory: convert to glob pattern for .md files only
        args+=("${arg%/}/**/*.md")
      else
        # File or glob pattern
        args+=("$arg")
      fi
    done

    markdownlint-cli2 "${args[@]}"
  fi
}

# md-mermaid-lint wrapper with smart path resolution
mermaidlint() {
  # Check if md-mermaid-lint is available
  if ! command -v md-mermaid-lint &>/dev/null; then
    echo "Error: md-mermaid-lint is not installed" >&2
    echo "Install with: mise install" >&2
    return 1
  fi

  # Default to current directory if no arguments
  if [ $# -eq 0 ]; then
    set -- "**/*.md"
  fi

  # Convert paths to glob patterns
  local patterns=()
  for arg in "$@"; do
    # Skip flags (starting with -)
    if [[ "$arg" == -* ]]; then
      patterns+=("$arg")
    # If directory, append /**/*.md
    elif [ -d "$arg" ]; then
      patterns+=("$arg/**/*.md")
    else
      # File or glob pattern
      patterns+=("$arg")
    fi
  done

  md-mermaid-lint "${patterns[@]}"
  return $?
}

# Claude Code teleport wrapper for SSH Host Alias environments
# Temporarily converts git remote URL to standard format for teleport compatibility
teleport() {
  if [ -z "$1" ]; then
    echo "Usage: teleport <session-id>" >&2
    echo "Example: teleport session_xxxxx" >&2
    return 1
  fi

  local session_id="$1"

  # Check if we're in a git repository
  if ! git rev-parse --git-dir &>/dev/null; then
    echo "Error: Not in a git repository" >&2
    return 1
  fi

  # Get current origin URL
  local original_url
  if ! original_url=$(git remote get-url origin 2>/dev/null); then
    echo "Error: No origin remote found" >&2
    return 1
  fi

  echo "📌 Original URL: $original_url"

  # Check if URL is in SSH format (git@...)
  if ! echo "$original_url" | grep -qE '^git@'; then
    echo "ℹ️  Not an SSH URL format, running teleport directly"
    claude --teleport "$session_id"
    return $?
  fi

  # Convert SSH Host Alias to standard format
  # e.g., github.com-rysk-tanaka -> github.com
  local standard_url
  standard_url=$(echo "$original_url" | sed -E 's/github\.com-[^:]+:/github.com:/')

  # Check if conversion is needed
  if [ "$original_url" = "$standard_url" ]; then
    echo "ℹ️  URL is already in standard format"
    claude --teleport "$session_id"
    return $?
  fi

  echo "🔄 Temporary URL: $standard_url"

  # Setup cleanup handler
  local cleanup_done=0
  cleanup() {
    if [ $cleanup_done -eq 0 ]; then
      echo "↩️  Restoring original URL"
      git remote set-url origin "$original_url"
      cleanup_done=1
    fi
  }
  trap cleanup EXIT INT TERM

  # Temporarily change URL
  if ! git remote set-url origin "$standard_url"; then
    echo "Error: Failed to change remote URL" >&2
    return 1
  fi

  # Run claude teleport
  echo "🚀 Running claude --teleport $session_id"
  claude --teleport "$session_id"
  local exit_code=$?

  # Restore original URL
  trap - EXIT INT TERM
  cleanup

  if [ $exit_code -eq 0 ]; then
    echo "✅ Done!"
  else
    echo "❌ Teleport failed with exit code $exit_code" >&2
  fi

  return $exit_code
}
