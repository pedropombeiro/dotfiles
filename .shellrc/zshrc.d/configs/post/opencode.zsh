#!/usr/bin/env zsh

# Session-ID completion for `opencode -s` / `--session`.
#
# `opencode completion` (cached as ~/.config/zsh/site-functions/_opencode by
# pre/060-generate-completions.zsh) delegates everything to yargs, which knows
# `-s` takes a string but has no idea what the valid session IDs are. This
# wraps that generated completer so the word after `-s` offers real sessions
# (ID as the inserted value, title + timestamp as the description) and every
# other completion context falls through to yargs unchanged.
#
# fzf-tab (loaded in common-plugins.zsh) turns the resulting `_describe` group
# into the interactive fzf picker; no fzf call is made here directly, so the
# completion still works with a plain zsh menu if fzf-tab is absent.

(( $+commands[opencode] )) || return
# jq parses the `--format json` output; without it, leave the generated
# completion untouched rather than shipping a fragile table-scraping fallback.
(( $+commands[jq] )) || return

# $EPOCHSECONDS (used to render relative session ages) comes from this module and
# is empty without it, which would silently break the jq invocation below.
zmodload -F zsh/datetime +p:EPOCHSECONDS 2>/dev/null || return

# Number of most recent sessions to offer. `opencode session list` is already
# scoped to the current project, so this is a per-project window.
: ${OPENCODE_COMPLETE_SESSION_COUNT:=100}

# Even with --pure, `opencode session list` costs ~0.6s, which is too slow to
# run on every keystroke-triggered completion. Cache per project and reuse for a
# few seconds so repeated tabs and fzf-tab redraws stay responsive.
: ${OPENCODE_COMPLETE_SESSION_TTL:=15}

_opencode_session_cache_file() {
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/opencode/completion"
  [[ -d $dir ]] || mkdir -p $dir

  # `opencode session list` scopes to the project (git worktree root), not $PWD:
  # running it from a subdirectory returns the same sessions as the root. Key the
  # cache on the worktree root so every subdirectory of a repo shares one entry
  # instead of triggering a fresh ~1.5s fetch per directory. Outside a repo,
  # opencode treats the directory itself as the scope, so fall back to $PWD.
  local root=$(git rev-parse --show-toplevel 2>/dev/null) || root=""
  [[ -n $root ]] || root=$PWD

  # ${root//\//%} flattens the path into a single filename component.
  print -r -- "$dir/sessions${root//\//%}.json"
}

# Populates the `reply` array with "id:description" entries for _describe.
_opencode_session_matches() {
  local cache=$(_opencode_session_cache_file)

  # (Nms-N) = exists and modified less than N seconds ago. This must be an array
  # assignment, not a [[ ]] test: [[ ]] never performs filename generation, so a
  # glob qualifier there silently evaluates as a literal string and always "matches".
  local -a fresh=( ${cache}(Nms-${OPENCODE_COMPLETE_SESSION_TTL}) )

  # Refresh on a miss, writing via a temp file so a killed or failed run cannot
  # leave a truncated cache that later reads would treat as an empty session list.
  if (( ! $#fresh )); then
    local tmp="${cache}.tmp.$$"
    # --pure skips loading external plugins, which session listing does not need.
    # In plugin-heavy projects this is the difference between ~14s and ~0.6s; the
    # JSON is byte-identical either way.
    if opencode --pure session list -n $OPENCODE_COMPLETE_SESSION_COUNT --format json >$tmp 2>/dev/null \
      && [[ -s $tmp ]]; then
      mv -f $tmp $cache
    else
      rm -f $tmp
      # Fall back to a stale cache if one exists; otherwise there is nothing to offer.
      [[ -s $cache ]] || return 1
    fi
  fi

  # Pad titles to a fixed width so the timestamps line up as a right-hand column.
  # Budget: terminal width minus the 30-char session ID that _describe shows,
  # its " -- " list-separator, the timestamp column, and fzf's gutter/marker.
  # Capped at 52 (the p90 title length) so wide terminals do not strand the
  # timestamp column in a sea of padding, and floored so narrow ones stay usable.
  local -i title_width=$(( ${COLUMNS:-80} - 30 - 4 - 9 - 6 ))
  (( title_width > 52 )) && title_width=52
  (( title_width >= 24 )) || title_width=24

  # `updated` is epoch milliseconds. Untitled sessions get a placeholder so the
  # description column is never empty. Colons are safe inside the description;
  # _describe only splits on the first colon, and session IDs contain none.
  #
  # gsub("\\s+"; " ") collapses embedded newlines/tabs into spaces: the reply is
  # split on newlines by ${(f)}, so a multi-line title would otherwise desync the
  # list and inject a bogus candidate whose "ID" is a fragment of the title.
  #
  # Relative ages ("3h ago") scan faster than absolute dates for recent sessions,
  # which is the common case; anything older than a week falls back to "Mon DD".
  # No ANSI colouring here: fzf runs with --ansi and strips escapes from the line
  # it prints, so a coloured display string would no longer match the key fzf-tab
  # stored in _ftb_compcap and selection would silently fail.
  reply=( ${(f)"$(jq -r --argjson w $title_width --argjson now "$EPOCHSECONDS" '
    def pad($s; $n): if ($s | length) > $n
      then ($s[0:$n-1] + "…")
      else ($s + (" " * ($n - ($s | length)))) end;
    def rel($secs): ($now - $secs) as $d |
      if   $d < 60     then "just now"
      elif $d < 3600   then "\(($d / 60)     | floor)m ago"
      elif $d < 86400  then "\(($d / 3600)   | floor)h ago"
      elif $d < 604800 then "\(($d / 86400)  | floor)d ago"
      else ($secs | localtime | strftime("%b %d")) end;
    .[] |
    (.title // "" | gsub("\\s+"; " ") | sub("^ +"; "") | sub(" +$"; "")) as $title |
    (.updated / 1000 | floor) as $secs |
    "\(.id):\(pad(if $title == "" then "(untitled)" else $title end; $w))  \(rel($secs))"
  ' $cache 2>/dev/null)"} )

  (( $#reply ))
}

_opencode_complete_session() {
  local -a reply
  _opencode_session_matches || return 1
  # -V keeps the list in `session list` order (most recent first) instead of
  # letting the completion system sort the IDs alphabetically, which would be
  # meaningless for opaque IDs. It must precede the description: any argument
  # after the array name is forwarded to compadd, where a trailing -V swallows
  # the next word and leaks _describe internals into the candidate list.
  _describe -V -t opencode-sessions 'opencode session' reply
}

_opencode_complete() {
  # Detect `-s <TAB>`, `--session <TAB>`, and `--session=<TAB>`.
  local prev=${words[CURRENT-1]}
  if [[ $prev == (-s|--session) ]]; then
    _opencode_complete_session && return
  elif [[ ${words[CURRENT]} == --session=* ]]; then
    compset -P '--session='
    _opencode_complete_session && return
  fi

  # Everything else: hand back to the generated yargs completer.
  if (( $+functions[_opencode_yargs_completions] )); then
    _opencode_yargs_completions "$@"
  else
    _default
  fi
}

# The generated _opencode is an autoload stub whose body is the whole upstream
# script: it defines _opencode_yargs_completions, then registers it via compdef.
# Force-load it and run it once so that helper exists as a global function,
# then reclaim the `opencode` binding for the wrapper above. Deferred to a
# zinit turbo slot after fzf-tab (wait'0a') so the compdef lands last and is
# not overwritten by fzf-tab's own completion setup.
_opencode_install_completion() {
  if (( ! $+functions[_opencode_yargs_completions] )); then
    autoload -Uz +X _opencode 2>/dev/null
    # Runs the else-branch of the upstream script (a compdef call), which is
    # harmless here and leaves the helper function defined globally.
    (( $+functions[_opencode] )) && _opencode 2>/dev/null
  fi

  compdef _opencode_complete opencode
  # `oc` is the model-aware opencode wrapper from ~/.shellrc/rc.d/aliases.sh.
  (( $+functions[oc] )) && compdef _opencode_complete oc
}

# Session titles are long, so give fzf a tall window. --no-sort makes fzf
# preserve the most-recent-first order that `_describe -V` produces; without it
# fzf re-sorts alphabetically by session ID, which is meaningless here.
# The completion runs with curcontext `:complete:opencode:` (empty argument
# field), so the fzf-tab context needs a trailing wildcard to match.
zstyle ':fzf-tab:complete:(opencode|oc):*' fzf-flags --no-sort --height=60% --reverse

# fzf-tab sorts its candidate list itself (lib/-ftb-generate-complist) before
# fzf ever sees it, so --no-sort alone is not enough; it checks the `sort` style
# under ":completion:${curcontext#:}". Without this, sessions come back ordered
# by opaque ID instead of recency. fzf-tab does not include the tag in that
# context, so this necessarily covers all opencode completions - harmless, since
# the only other candidates are yargs subcommands and flags, which are then
# offered in their natural definition order rather than alphabetically.
zstyle ':completion:complete:(opencode|oc):*' sort false

zinit wait'0b' lucid nocd light-mode for \
  atload'_opencode_install_completion' \
  zdharma-continuum/null
