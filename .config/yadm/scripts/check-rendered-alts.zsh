#!/usr/bin/env zsh
#
# Validate the result of `yadm alt` for the current machine identity. CI runs
# this in a scratch HOME once per class so broken templates and alternates show
# up before they reach a machine.
#
# Checks:
#   - no broken untracked symlinks in directories that hold tracked files
#   - every unconditional `##template` rendered to a regular file; templates
#     with other conditions are validated only where they rendered
#   - rendered templates contain no leftover `{{` or `{%` markers
#   - rendered `.json` parses with jq and rendered `.lua` compiles with luac

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )" &>/dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

# Query the repo with plain git: `yadm config local.*` and git passthrough
# commands trigger auto-alt, which would re-render the files under test.
repo=$(yadm introspect repo)
ygit() { git -C "${HOME}" --git-dir="${repo}" --work-tree="${HOME}" "$@"; }

local -a tracked=( "${(@f)$(ygit ls-files)}" )
local -a dirs=( "${(@u)tracked:h}" )
local -a errors=()

local dir link
for dir in "${dirs[@]}"; do
  # N = nullglob, D = include dotfiles, -@ = broken symlinks
  for link in "${HOME}/${dir}"/*(ND-@); do
    # Tracked symlinks (like skills.work/caproni) point into repos that only
    # some machines clone; only links that yadm alt creates must resolve.
    (( ${tracked[(Ie)${link#${HOME}/}]} )) && continue
    errors+=("broken symlink: ${link#${HOME}/} -> $(readlink "${link}")")
  done
done

local template target
for template in ${(M)tracked:#*\#\#*}; do
  # `template` or `t` may appear anywhere in the condition list, optionally
  # with a processor suffix such as `template.j2`
  [[ ,${template#*\#\#}, =~ ',(t|template)(\.[^,]*)?,' ]] || continue
  target="${HOME}/${template%%\#\#*}"
  if [[ ! -f ${target} || -L ${target} ]]; then
    # Templates with other conditions may rightly not apply to this machine
    [[ ${template#*\#\#} =~ '^(t|template)(\.[^,]*)?$' ]] && errors+=("template not rendered: ${template}")
    continue
  fi
  if grep -qE '\{\{|\{%' "${target}"; then
    errors+=("leftover template markers: ${target#${HOME}/}")
  fi
  case ${target} in
    *.json)
      jq empty "${target}" 2>/dev/null || errors+=("invalid JSON: ${target#${HOME}/}")
      ;;
    *.lua)
      luac -p "${target}" 2>/dev/null || errors+=("invalid Lua: ${target#${HOME}/}")
      ;;
  esac
done

local identity="class=$(ygit config local.class) os=$(ygit config local.os) distro=$(ygit config local.distro)"
if (( ${#errors} > 0 )); then
  printf "${RED}%s${NC}\n" "Rendered alternates failed for ${identity}:"
  printf '  %s\n' "${errors[@]}"
  exit 1
fi

printf "${GREEN}%s${NC}\n" "Rendered alternates OK for ${identity}."
