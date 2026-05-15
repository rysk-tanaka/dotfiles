# mise shims (loaded for all zsh sessions including non-interactive)
export PATH="$HOME/.local/share/mise/shims:$PATH"

# Editor (vim for git commit, Zed for gitu file viewer)
export GIT_EDITOR="vim"
export GITU_SHOW_EDITOR="zed"

# Skip optional locks in `git status` etc. to avoid index.lock contention
# with devcontainers sharing the same worktree via bind mount.
export GIT_OPTIONAL_LOCKS=0

# GitHub token for MCP server (gh auth token via OAuth, not PAT)
# - MCP-specific var to avoid interfering with gh CLI's own token resolution
# - No --hostname flag: returns active account's token, respects `gh auth switch`
if [ -z "$GH_MCP_TOKEN" ] && command -v gh >/dev/null 2>&1; then
  _gh_token="$(gh auth token 2>/dev/null)"
  [ -n "$_gh_token" ] && export GH_MCP_TOKEN="$_gh_token"
  unset _gh_token
fi

# Clone Claude Code plugin marketplaces over HTTPS instead of SSH
# Avoids 1Password SSH-key approval prompts at session start (claude-code#14485)
export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1

# zoxide (required for non-interactive shells like Claude Code)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi
