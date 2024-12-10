# zsh-syntax-highlighting
autoload -Uz colors && colors

# zsh-completions
# zsh-autosuggestionsource
# zsh-git-prompt
if type brew &>/dev/null; then
  FPATH=/opt/homebrew/share/zsh-completions:$FPATH
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source /opt/homebrew/opt/zsh-git-prompt/zshrc.sh

  autoload -Uz compinit
  compinit
  PROMPT="%F{034}%n%f:%F{033}%~%f $(git_super_status)"$'\n'"%(#.#.$) "
fi

# mise
if type mise &>/dev/null; then
  eval "$(mise activate zsh)"
  eval "$(mise activate --shims)"
fi

# python
alias python="/usr/bin/python3"
alias pip="/usr/bin/pip3"

# pbcopy
alias pbcopy="ghead -c -1 | pbcopy"

# ls
alias ls="ls -G"
alias la="ls -a"
alias ll="ls -alF"

# eza
alias le="eza --git -l"
alias lt="le -snew"

# delta
alias diff="delta"

# rg
alias rg="rg --hidden --no-ignore-vcs --ignore-case"

# gnu utils
# alias sed="gsed"
# alias cp="gcp"
# alias grep="ggrep --exclude-dir={venv,node_modules,dist}"
