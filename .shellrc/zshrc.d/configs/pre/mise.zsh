#!/usr/bin/env zsh

if [ -x "${HOME}/.local/share/mise/bin/mise" ]; then
  export RTX_DISABLE_DIRENV_WARNING=1

  eval "$("${HOME}/.local/share/mise/bin/mise" activate zsh)"
elif command -v mise >/dev/null; then
  export RTX_DISABLE_DIRENV_WARNING=1

  eval "$(mise activate zsh)"
fi

if [[ -n $MISE_SHELL ]]; then
  if [ ! -f ~/.config/zsh/site-functions/_mise ]; then
    mise complete -s zsh >~/.config/zsh/site-functions/_mise
    rm -f '~/.zcompdump*' >/dev/null 2>&1
  fi
fi
