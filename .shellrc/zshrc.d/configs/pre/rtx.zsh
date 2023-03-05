#!/usr/bin/env zsh

if [ -x "${HOME}/.local/share/rtx/bin/rtx" ]; then
  export RTX_DISABLE_DIRENV_WARNING=1

  eval "$("${HOME}/.local/share/rtx/bin/rtx" activate zsh)"
elif command -v rtx >/dev/null; then
  export RTX_DISABLE_DIRENV_WARNING=1

  eval "$(rtx activate zsh)"
fi

if [[ -n $RTX_SHELL ]]; then
  if [ ! -f  ~/.config/zsh/site-functions/_rtx ]; then
    rtx complete -s zsh > ~/.config/zsh/site-functions/_rtx
    rm -f '~/.zcompdump*' >/dev/null 2>&1
  fi
fi
