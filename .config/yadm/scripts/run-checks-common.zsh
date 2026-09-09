#!/usr/bin/env zsh

setopt LOCAL_OPTIONS EXTENDED_GLOB

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

function print_op() {
  printf "${CYAN}%s${NC}\n" "- $1"
}

function print_op_stay() {
  printf "${CYAN}%-63s${NC} " "- $1..."
}

function print_ok() {
  printf "${GREEN}%s${NC} %s\n" '✅ OK' $1
}

function print_failure() {
  printf "${RED}%s${NC}\n" "$1"
}

function print_warn() {
  printf "${YELLOW}%s${NC} %s\n" '⚠️  WARN' "$1"
}

any_failed=0

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

# Slugify a markdown heading line the way GitHub/GitLab anchors do: strip the
# leading #s, lowercase, drop everything but alphanumerics/spaces/hyphens, then
# spaces to hyphens.
function _slugify_heading() {
  local h="$1"
  h="${h##\###[[:space:]]#}"
  h="${(L)h}"
  h="${h//[^a-z0-9 -]/}"
  echo "${h// /-}"
}

# Relative links between agent docs are invisible to every linter we run, so a
# renamed heading or moved file rots silently until an agent follows the link.
function check_agent_doc_links() {
  print_op_stay "Checking ~/.agents/docs links and anchors"

  local docs_dir="$HOME/.agents/docs"
  if [[ ! -d "$docs_dir" ]]; then
    print_ok "(skipped, no docs dir)"
    return
  fi

  local -a broken
  local f dir m link target anchor heading found
  for f in "$docs_dir"/**/*.md(N); do
    dir="${f:h}"
    for m in ${(f)"$(grep -oE '\]\([^)]+\.md(#[A-Za-z0-9._-]+)?\)' "$f" 2>/dev/null)"}; do
      link="${m#\]\(}"
      link="${link%\)}"
      # Only relative links are ours to validate; skip URLs and absolute paths.
      case "$link" in http*|'~'*|/*) continue ;; esac

      target="${link%%\#*}"
      anchor=""
      [[ "$link" == *'#'* ]] && anchor="${link#*\#}"

      if [[ ! -f "$dir/$target" ]]; then
        broken+=("${f:t} -> $link (no such file)")
        continue
      fi

      [[ -n "$anchor" ]] || continue
      found=0
      while IFS= read -r heading; do
        if [[ "$(_slugify_heading "$heading")" == "$anchor" ]]; then
          found=1
          break
        fi
      done < <(grep -E '^#{1,6} ' "$dir/$target")
      (( found )) || broken+=("${f:t} -> $link (no such heading)")
    done
  done

  if (( ${#broken} == 0 )); then
    print_ok
  else
    echo
    local b
    for b in "${broken[@]}"; do
      print_warn "$b"
    done
  fi
}

# A vendored skill removed from disk without updating .skill-lock.json gets
# silently reinstalled on the next skill update.
function check_skill_lock_orphans() {
  print_op_stay "Checking .skill-lock.json entries have directories"

  local lock="$HOME/.agents/.skill-lock.json"
  if [[ ! -f "$lock" ]]; then
    print_ok "(skipped, no lock file)"
    return
  fi

  local -a orphans
  local s
  for s in ${(f)"$(jq -r '.skills | keys[]' "$lock" 2>/dev/null)"}; do
    [[ -n "$s" && ! -d "$HOME/.agents/skills/$s" ]] && orphans+=("$s")
  done

  # The reverse (a directory with no lock entry) is normal: hand-authored
  # skills are never in the lock file.
  if (( ${#orphans} == 0 )); then
    print_ok
  else
    echo
    for s in "${orphans[@]}"; do
      print_warn "$s in .skill-lock.json but not installed"
    done
  fi
}

check_agent_doc_links
check_skill_lock_orphans

# Runs in a subshell: the check defines its own print helpers and an allowlist
# that must not leak into the shared namespace here.
if [[ -x "${YADM_SCRIPTS}/check-glibc-compat.zsh" ]]; then
  "${YADM_SCRIPTS}/check-glibc-compat.zsh" || any_failed=1
fi
