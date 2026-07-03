# mise shims (loaded for all zsh sessions including non-interactive)
export PATH="$HOME/.local/share/mise/shims:$PATH"

# Editor (vim for git commit, Zed for gitu file viewer)
export GIT_EDITOR="vim"
export GITU_SHOW_EDITOR="zed"

# Skip optional locks in `git status` etc. to avoid index.lock contention
# with devcontainers sharing the same worktree via bind mount.
export GIT_OPTIONAL_LOCKS=0

# Skip auto_updates casks in `brew upgrade`.
# These update themselves in-app; letting brew touch them causes sudo prompts
# and Caskroom staging conflicts on already-running apps.
export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1

# The cmux LaunchAgent injects GH_TOKEN into the GUI session, and terminals inherit it.
# gh always prefers GH_TOKEN over the keyring, so that inherited value would pin the CLI
# to whatever account was active at login and silently override `gh auth switch`. Drop it
# here so the gh CLI (and the `gh auth token` call below) follow the keyring active account.
# cmux reads the launchd-set GH_TOKEN directly, so unsetting the shell copy does not affect it.
unset GH_TOKEN

# GitHub tokens for MCP server and mise (gh auth token via OAuth, not PAT)
# - Tool-specific vars (not GITHUB_TOKEN) to avoid interfering with gh CLI's own token resolution
# - No --hostname flag: returns active account's token, respects `gh auth switch`
# - MISE_GITHUB_TOKEN: aqua/ubi backends resolve versions via api.github.com; unauthenticated
#   requests share the per-IP 60 req/h quota and bulk runs (sync-tools) exhaust it
if [ -z "$GH_MCP_TOKEN" ] && command -v gh >/dev/null 2>&1; then
  _gh_token="$(gh auth token 2>/dev/null)"
  if [ -n "$_gh_token" ]; then
    export GH_MCP_TOKEN="$_gh_token"
    export MISE_GITHUB_TOKEN="$_gh_token"
  fi
  unset _gh_token
fi

# Clone Claude Code plugin marketplaces over HTTPS instead of SSH
# Avoids 1Password SSH-key approval prompts at session start (claude-code#14485)
export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1

# zoxide (required for non-interactive shells like Claude Code)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi
