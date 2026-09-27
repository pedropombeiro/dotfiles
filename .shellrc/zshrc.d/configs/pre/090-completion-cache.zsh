#!/usr/bin/env zsh

# Check after generating all site-functions, before the single compinit.
# Ignore files without completion headers so they cannot cause a rebuild loop.
if [[ -f $HOME/.zcompdump ]]; then
  local _dump_content="$(<$HOME/.zcompdump)"
  local _reason="" _first_line="" f=""
  for f in $HOME/.config/zsh/site-functions/_*(N.); do
    _first_line=
    IFS= read -r _first_line < "$f" 2>/dev/null
    [[ "$_first_line" == "#compdef "* || "$_first_line" == "#autoload"* ]] || continue
    if [[ $f -nt $HOME/.zcompdump ]]; then
      _reason="${f:t} is newer than .zcompdump"
      break
    fi
    if [[ "$_dump_content" != *"${f:t}"* ]]; then
      _reason="${f:t} is missing from .zcompdump"
      break
    fi
  done

  if [[ -n $_reason ]]; then
    print -P "%F{yellow}[zsh] Rebuilding .zcompdump: ${_reason}%f"
    rm -f $HOME/.zcompdump*(N) 2>/dev/null
  fi
fi

# Retain periodic refresh for changes outside our generated site-functions.
local -a _stale_dumps=($HOME/.zcompdump*(N.md+1))
if (( $#_stale_dumps )); then
  rm -f -- "${_stale_dumps[@]}" 2>/dev/null
fi
