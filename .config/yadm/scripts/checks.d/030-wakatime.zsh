#!/usr/bin/env zsh

set -o pipefail
setopt EXTENDED_GLOB
source "${${(%):-%x}:A:h:h}/check-helpers.zsh"

WAKATIME_CLI="$HOME/.wakatime/wakatime-cli"
if [[ -x "$WAKATIME_CLI" ]]; then
  print_op_stay "Checking wakatime-cli import_cfg points to base cfg"
  # (f) splits on newlines, (M) keeps only matching elements, ## strips leading pattern
  import_cfg=${(M)${(f)"$(<$HOME/.wakatime.cfg)"}:#import_cfg*}
  import_cfg=${import_cfg##import_cfg[[:space:]]#=[[:space:]]#}
  import_cfg="${import_cfg/#\~/$HOME}"
  if [[ "$import_cfg" == "$HOME/.wakatime.base.cfg" ]]; then
    print_ok
  elif [[ -z "$import_cfg" ]]; then
    print_failure "import_cfg not found in ~/.wakatime.cfg"
    any_failed=1
  else
    print_failure "import_cfg points to '$import_cfg', expected ~/.wakatime.base.cfg"
    any_failed=1
  fi

  print_op_stay "Checking ~/.wakatime-project does not exist"
  if [[ ! -f "$HOME/.wakatime-project" ]]; then
    print_ok
  else
    print_failure "~/.wakatime-project exists and will override project detection for all subdirectories"
    any_failed=1
  fi

wakatime_project_from_heartbeat() {
  local entity="$1"
  # Escape regex metacharacters (e.g. '.') so the entity path is matched
  # literally. Slashes are not special in grep BRE, so they are left as-is
  # to avoid GNU grep's "stray \ before /" warnings.
  local entity_re
  entity_re=$(printf '%s' "$entity" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
  local output project rc
  output=$(cd "$HOME" && "$WAKATIME_CLI" --entity "$entity" --project-folder "$2" \
    --heartbeat-rate-limit-seconds 0 --disable-offline \
    --timeout 5 --sync-ai-disabled --verbose --log-to-stdout 2>&1)
  rc=$?
  if (( rc != 0 )); then
    print -ru2 -- "WakaTime CLI failed (exit ${rc}) for ${entity}: ${output}"
    return 1
  fi
  # Match only this entity, excluding unrelated queued heartbeats.
  project=$(print -r -- "$output" \
      | grep -o 'heartbeats: \[.*\]' \
      | grep -o "{[^{}]*\\\\\"entity\\\\\":\\\\\"${entity_re}\\\\\"[^{}]*}" \
      | grep -o 'project\\":\\"[^\\]*\\"' \
      | sed -n '1{s/project\\":\\"//;s/\\"//;p;}')
  if [[ -z "$project" ]]; then
    if [[ "$output" == *'heartbeats: ['* ]]; then
      print -ru2 -- "WakaTime emitted heartbeats, but no project could be parsed for ${entity}"
    else
      print -ru2 -- "WakaTime emitted no heartbeat log for ${entity}"
    fi
    return 1
  fi
  print -r -- "$project"
}

# Use a tracked file whose resolved path stays inside the repository.
# The GDK README is a symlink into dotfiles and is unsuitable for this probe.
wakatime_probe_file() {
  local repo=${1:A} rel candidate files
  if ! files=$(cd "$repo" && git ls-files -z); then
    print -ru2 -- "Cannot list tracked files in ${repo}"
    return 2
  fi
  for rel in "${(@0)files}"; do
    candidate="$repo/$rel"
    if [[ -f "$candidate" && "${candidate:A}" == "$repo/"* ]]; then
      printf '%s\n' "${candidate:A}"
      return 0
    fi
  done
  return 1
}

# Retry failed probes, preserving the final diagnostic for the caller.
wakatime_project_from_heartbeat_retry() {
  local entity=$1 folder=$2 result i
  for i in 1 2 3; do
    if result=$(wakatime_project_from_heartbeat "$entity" "$folder" 2>&1); then
      printf '%s\n' "$result"
      return 0
    fi
    (( i < 3 )) && sleep 1
  done
  print -ru2 -- "$result"
  return 1
}

  print_op_stay "Checking wakatime project detection for dotfiles"
  wakatime_project=$(wakatime_project_from_heartbeat_retry "$HOME/.zshrc" "$HOME")
  if [[ "$wakatime_project" == "dotfiles" ]]; then
    print_ok "$wakatime_project"
  else
    print_failure "Expected 'dotfiles', got '${wakatime_project:-<empty>}'"
    any_failed=1
  fi

  print_op_stay "Checking wakatime project detection for non-dotfile repos"
  test_repo=""
  if [[ -n "$GDK_ROOT" && -d "$GDK_ROOT/gitlab/.git" ]]; then
    test_repo="$GDK_ROOT/gitlab"
  elif [[ -z "$test_repo" ]]; then
    test_repo=${$(fd -td --hidden --no-ignore --max-depth 5 '^\.git$' "$HOME/Developer" -1 2>/dev/null)%/.git/}
  fi
  if [[ -n "$test_repo" ]]; then
    if test_entity=$(wakatime_probe_file "$test_repo"); then
      wakatime_project=$(wakatime_project_from_heartbeat_retry "$test_entity" "$test_repo")
      if [[ -n "$wakatime_project" && "$wakatime_project" != "dotfiles" ]]; then
        print_ok "$wakatime_project"
      else
        print_failure "Expected a non-dotfiles project name for ${test_entity}, got '${wakatime_project:-<empty>}'"
        any_failed=1
      fi
    else
      probe_rc=$?
      if (( probe_rc == 1 )); then
        print_ok "(skipped, no tracked regular file resolves inside $test_repo)"
      else
        print_failure "Could not select a WakaTime probe in ${test_repo}"
        any_failed=1
      fi
    fi
  else
    print_ok "(skipped, no test repo found)"
  fi
fi

exit "$any_failed"
