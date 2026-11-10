#!/usr/bin/env zsh

step_npm() {
  local output
  local -i rc=0
  # Tool upgrades can leave shims pointing at removed plugin paths.
  mise reshim --force
  (( $+commands[npm] )) || return 0
  output="$(npm update -g 2>&1)" || rc=$?
  print -r -- "${output}"
  (( rc == 0 )) || return ${rc}
  if [[ "${output}" == *'install scripts blocked because they are not covered by allowScripts'* ]]; then
    print -r -- "npm blocked a global package install script. Allow the named package explicitly, then rerun the update."
    return 1
  fi
}

_update_register "npm" step_npm
