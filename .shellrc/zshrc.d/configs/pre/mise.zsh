#!/usr/bin/env zsh

# Defer mise activation using zinit's turbo mode (null plugin is a no-op target)
zinit ice wait'0a' lucid atload'
  eval "$(mise activate zsh)"
  if [[ ! -f ~/.config/zsh/site-functions/_mise ]]; then
    mise complete -s zsh >~/.config/zsh/site-functions/_mise
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi

  # Load zoxide after mise makes it available (use --no-cmd to avoid zi conflict with zinit)
  if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh --no-cmd)"
    alias j="__zoxide_z"   # autojump compatibility
    alias jj="__zoxide_zi" # interactive mode
  fi
  # Load gh completion after mise makes it available
  command -v gh >/dev/null && eval "$(gh completion -s zsh)"

'
zinit light zdharma-continuum/null
