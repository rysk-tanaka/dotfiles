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
    # Expand now: the locals are gone by the time the EXIT trap fires
    # shellcheck disable=SC2064
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
    local current_dir
    current_dir=$(pwd)
    local cwd_prefix
    cwd_prefix=$(git rev-parse --show-prefix)
    local args=()
    local explicit_files=()

    # Convert paths to be relative to git root; globs (including globby-only
    # syntax) are passed through for markdownlint-cli2 to resolve
    while [ $# -gt 0 ]; do
      local arg="$1"
      shift
      if [[ "$arg" == --config ]]; then
        # Resolve against the caller's directory since lint runs from git root
        local config_path="$1"
        [[ "$config_path" = /* ]] || config_path="$current_dir/$config_path"
        args+=("$arg" "$config_path")
        shift
        continue
      fi
      if [[ "$arg" == --configPointer ]]; then
        args+=("$arg" "$1")
        shift
        continue
      fi
      if [[ "$arg" == -* ]] || { [ ! -d "$arg" ] && [ ! -f "$arg" ]; }; then
        args+=("$arg")
        continue
      fi

      # Collapse ./ and ../ so explicit files match the paths git reports,
      # keeping symlinked directories as their in-repo logical paths
      local rel_path="$cwd_prefix$arg"
      if [ "$arg" = "$git_root" ]; then
        rel_path=""
      elif [[ "$arg" = "$git_root"/* ]]; then
        rel_path="${arg#"$git_root"/}"
      elif [[ "$arg" = /* ]]; then
        rel_path="$arg"
      fi
      [[ "$rel_path" = /* ]] || rel_path=$(cd "$git_root" && perl -e '
        my @parts;
        for (split m{/}, $ARGV[0]) {
          next if $_ eq "" || $_ eq ".";
          # A .. after a symlink or an unresolved .. must stay as-is,
          # otherwise it would point somewhere other than the caller meant
          my $can_collapse = $_ eq ".." && @parts && $parts[-1] ne ".."
            && !-l join("/", @parts);
          if ($can_collapse) { pop @parts; next; }
          push @parts, $_;
        }
        print join("/", @parts);
      ' -- "$rel_path")
      # markdownlint-cli2 collapses .. lexically, so pass the real location
      # when a .. that crosses a symlink had to be kept
      if [[ "/$rel_path/" = */../* && "$rel_path" != ../* ]]; then
        # zsh's cd collapses .. before following symlinks, so use realpath
        rel_path=$(perl -MCwd -e 'print Cwd::realpath($ARGV[0])' -- "$arg")
      fi

      if [ -f "$arg" ]; then
        args+=("$rel_path")
        explicit_files+=("$rel_path")
        continue
      fi

      # Directory: only target markdown files
      if [ -z "$rel_path" ]; then
        args+=("**/*.md")
      else
        args+=("$rel_path/**/*.md")
      fi
    done

    if [ ${#args[@]} -eq 0 ]; then
      (cd "$git_root" && markdownlint-cli2)
      return
    fi

    # markdownlint-cli2 only honors .gitignore, so ask git for everything it
    # excludes (.git/info/exclude and core.excludesFile too) and for symlinked
    # directories that usually point into other repos, then pass them as
    # negated globs; explicitly named files and their parents stay lintable
    local negation
    local negations=()
    while IFS= read -r -d '' negation; do
      negations+=("$negation")
    done < <(
      cd "$git_root" &&
        {
          git ls-files -z --others --ignored --exclude-standard --directory
          git ls-files -z --cached --others --exclude-standard |
            perl -0 -ne 'chomp; print "$_/\0" if -l && -d'
        } | LC_ALL=C sort -zu | EXPLICIT_FILES="$(printf '%s\n' "${explicit_files[@]}")" perl -0 -ne '
          BEGIN { @explicit = grep { length } split /\n/, $ENV{EXPLICIT_FILES}; }
          chomp;
          my $entry = $_;
          # Ignored symlinks are reported without a trailing slash
          $entry .= "/" if $entry !~ m{/$} && -d $entry;
          my $is_dir = $entry =~ m{/$};
          # Only directories and Markdown files can affect lint targets
          next unless $is_dir || $entry =~ /\.(md|markdown)$/i;
          next if grep { index($entry, $_) == 0 } @excluded_dirs;
          next if grep { $_ eq $entry || ($is_dir && index($_, $entry) == 0) } @explicit;
          push @excluded_dirs, $entry if $is_dir;
          (my $glob = $entry) =~ s{/$}{};
          $glob =~ s/([][*?{}()#])/[$1]/g;
          # A backslash would be turned into a path separator by the CLI
          $glob =~ s/!/@(!)/g;
          print "!$glob", ($is_dir ? "/**" : ""), "\0";
        '
    )

    (cd "$git_root" && markdownlint-cli2 "${args[@]}" "${negations[@]}")
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

# Export Markdown to PDF/HTML/PNG/JPEG via the yzane/vscode-markdown-pdf CLI wrapper
# Setup: mise run setup-markdown-pdf (clones and builds the upstream extension)
mdpdf() {
  local ext_root="${MARKDOWN_PDF_EXT_ROOT:-$HOME/.cache/markdown-pdf-cli/vscode-markdown-pdf}"
  if [ ! -f "${ext_root}/dist/extension.js" ]; then
    echo "mdpdf: extension bundle not found. Run: mise run setup-markdown-pdf" >&2
    return 1
  fi
  MARKDOWN_PDF_EXT_ROOT="${ext_root}" node "${DOTFILES_PATH:-$HOME/Repositories/rysk/dotfiles}/.config/markdown-pdf-cli/markdown-pdf-cli.cjs" "$@"
}
