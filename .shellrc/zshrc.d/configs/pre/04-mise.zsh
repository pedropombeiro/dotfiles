#!/usr/bin/env zsh

for mise_path in "${HOME}/.local/share/mise/bin/mise" "${HOME}/.local/bin/mise" mise; do
  if command -v $mise_path >/dev/null; then
    export RTX_DISABLE_DIRENV_WARNING=1

    eval "$(${mise_path} activate zsh)"
  fi
done

if [[ -n $MISE_SHELL ]]; then
  if [[ ! -f ~/.config/zsh/site-functions/_mise ]]; then
    mise complete -s zsh >~/.config/zsh/site-functions/_mise
    rm -f '~/.zcompdump*' >/dev/null 2>&1
  fi
fi
