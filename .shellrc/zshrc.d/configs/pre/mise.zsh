#!/usr/bin/env zsh

# Defer mise activation using zinit's turbo mode (null plugin is a no-op target)
zinit ice wait'0a' lucid atload'
  eval "$(mise activate zsh)"
  if [[ ! -f ~/.config/zsh/site-functions/_mise ]]; then
    mise complete -s zsh >~/.config/zsh/site-functions/_mise
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi
'
zinit light zdharma-continuum/null
