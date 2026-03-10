#!/usr/bin/env zsh

mkdir -p $HOME/.config/zsh/site-functions
fpath=(
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}
  $HOME/.config/zsh/site-functions
  $fpath
)

# Invalidate compdump when site-functions are missing from it or files are newer
if [[ -f $HOME/.zcompdump ]]; then
  local _invalidate=0

  for f in $HOME/.config/zsh/site-functions/_*(N.); do
    if [[ $f -nt $HOME/.zcompdump ]]; then
      _invalidate=1
      break
    fi
    local _fname=${f:t}
    if ! grep -q "$_fname" $HOME/.zcompdump 2>/dev/null; then
      _invalidate=1
      break
    fi
  done

  if (( _invalidate )); then
    rm -f $HOME/.zcompdump*(N) 2>/dev/null
  fi
  unset f _fname _invalidate
fi

# Also recreate any compdump older than a day (using zsh glob instead of slow find)
# (N) = nullglob, (.) = regular files, (md+1) = modified more than 1 day ago
rm -f $HOME/.zcompdump*(N.md+1) 2>/dev/null
