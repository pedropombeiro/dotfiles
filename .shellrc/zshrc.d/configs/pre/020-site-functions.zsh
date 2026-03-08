#!/usr/bin/env zsh

mkdir -p $HOME/.config/zsh/site-functions
fpath=(
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}
  $HOME/.config/zsh/site-functions
  $fpath
)

# Invalidate compdump when any site-function is newer (catches completion regeneration)
if [[ -f $HOME/.zcompdump ]]; then
  for f in $HOME/.config/zsh/site-functions/*(N.); do
    if [[ $f -nt $HOME/.zcompdump ]]; then
      rm -f $HOME/.zcompdump*(N) 2>/dev/null
      break
    fi
  done
  unset f
fi

# Also recreate any compdump older than a day (using zsh glob instead of slow find)
# (N) = nullglob, (.) = regular files, (md+1) = modified more than 1 day ago
rm -f $HOME/.zcompdump*(N.md+1) 2>/dev/null
