# mise shims (loaded for all zsh sessions including non-interactive)
export PATH="$HOME/.local/share/mise/shims:$PATH"

# GitHub token for MCP server (gh auth token via OAuth, not PAT)
# - MCP-specific var to avoid interfering with gh CLI's own token resolution
# - No --hostname flag: returns active account's token, respects `gh auth switch`
if [ -z "$GH_MCP_TOKEN" ] && command -v gh >/dev/null 2>&1; then
  _gh_token="$(gh auth token 2>/dev/null)"
  [ -n "$_gh_token" ] && export GH_MCP_TOKEN="$_gh_token"
  unset _gh_token
fi

# zoxide (required for non-interactive shells like Claude Code)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi
