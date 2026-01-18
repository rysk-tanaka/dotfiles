# mise shims (loaded for all zsh sessions including non-interactive)
export PATH="$HOME/.local/share/mise/shims:$PATH"

# zoxide (required for non-interactive shells like Claude Code)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi
