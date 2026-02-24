#!/usr/bin/env zsh

mkdir -p $HOME/.config/zsh/site-functions
fpath=(
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}
  $HOME/.config/zsh/site-functions
  $fpath
)

if command -v mise &>/dev/null; then
  mise_bin=$(command -v mise)
  if [[ ! -f ~/.config/zsh/site-functions/_mise || ~/.config/zsh/site-functions/_mise -ot $mise_bin ]]; then
    mise complete -s zsh >~/.config/zsh/site-functions/_mise
    rm -f ~/.zcompdump* >/dev/null 2>&1
  fi
fi

# Recreate any compdump older than a day (using zsh glob instead of slow find)
# (N) = nullglob, (.) = regular files, (md+1) = modified more than 1 day ago
rm -f $HOME/.zcompdump*(N.md+1) 2>/dev/null
