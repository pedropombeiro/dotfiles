#!/usr/bin/env zsh

mkdir -p $HOME/.config/zsh/site-functions
fpath=(
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}
  $HOME/.config/zsh/site-functions
  $fpath
)

# Invalidate compdump when valid site-functions are missing from it or files are newer.
# Only check files with a #compdef header — compinit ignores files without one,
# so including them here would cause a rebuild loop every startup.
if [[ -f $HOME/.zcompdump ]]; then
  local _invalidate=0
  local _dump_content="$(<$HOME/.zcompdump)"

  local _reason="" _first_line
  for f in $HOME/.config/zsh/site-functions/_*(N.); do
    _first_line=
    IFS= read -r _first_line < "$f" 2>/dev/null
    [[ "$_first_line" == "#compdef "* || "$_first_line" == "#autoload"* ]] || continue
    if [[ $f -nt $HOME/.zcompdump ]]; then
      _invalidate=1
      _reason="${f:t} is newer than .zcompdump"
      break
    fi
    if [[ "$_dump_content" != *"${f:t}"* ]]; then
      _invalidate=1
      _reason="${f:t} is missing from .zcompdump"
      break
    fi
  done

  if (( _invalidate )); then
    print -P "%F{yellow}[zsh] Rebuilding .zcompdump: ${_reason}%f"
    rm -f $HOME/.zcompdump*(N) 2>/dev/null
  fi
  unset f _dump_content _invalidate _reason _first_line
fi

# Also recreate any compdump older than a day (using zsh glob instead of slow find)
# (N) = nullglob, (.) = regular files, (md+1) = modified more than 1 day ago
rm -f $HOME/.zcompdump*(N.md+1) 2>/dev/null
