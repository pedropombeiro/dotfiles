#!/usr/bin/env zsh

set -eu

class=$(yadm config local.class || true)
work_dir="${HOME}/.agents/skills.work"
source "${0:A:h}/lib/work-skills.zsh"

mkdir -p "${work_dir}"

sync_work_skills() {
  local name base source target
  for name in "${work_skills[@]}"; do
    target="${work_dir}/${name}"
    for base in "${HOME}/.agents/skills" "${HOME}/.claude/skills" "${HOME}/.config/opencode/skills"; do
      source="${base}/${name}"
      [[ -e "${source}" || -L "${source}" ]] || continue
      if [[ -L "${source}" ]]; then
        if [[ ! -e "${target}" && ! -L "${target}" ]]; then
          ln -s "${source:A}" "${target}"
        fi
        unlink "${source}"
      elif [[ ! -e "${target}" && ! -L "${target}" ]]; then
        mv "${source}" "${target}"
      elif [[ -d "${target}" && ! -L "${target}" ]] &&
        jq -e --arg n "${name}" '.skills | has($n)' "${HOME}/.agents/.skill-lock.json" >/dev/null 2>&1; then
        # npx skills reinstalls managed snapshots into the shared directory.
        rsync -a --delete "${source}/" "${target}/"
        rm -r "${source}"
      else
        print -u2 "Conflicting skill directories: ${source} and ${target}"
        return 1
      fi
    done
  done
}

sync_work_skills

if [[ "${class}" == Work ]]; then
  typeset -A sources=(
    caproni "${HOME}/.config/dotfiles/gitlab/.opencode/skills/caproni"
    devex-clickhouse "${HOME}/Developer/gitlab.com/gitlab-org/quality/analytics/team/.skills/clickhouse"
    fpf-report "${HOME}/Developer/gitlab.com/gitlab-org/ci-cd/fix-pipeline-flow-report/skill"
    orbit "${HOME}/Developer/gitlab.com/gitlab-org/orbit/knowledge-graph/skills/orbit"
  )
  for name in gitlab-babysit-mr gitlab-pipeline-watch glab-glql; do
    sources[${name}]="${HOME}/Developer/gitlab.com/gitlab-org/ai/skills/skills/${name}"
  done
  for name source in "${(@kv)sources}"; do
    target="${work_dir}/${name}"
    if [[ -d "${source}" && ! -e "${target}" && ! -L "${target}" ]]; then
      ln -s "${source}" "${target}"
    fi
  done
fi

if [[ "${1:-}" == --update && -f "${HOME}/.agents/.skill-lock.json" ]] && (( $+commands[npx] )); then
  typeset -a skills_to_update=()
  skill_names=$(jq -r '.skills | keys[]' "${HOME}/.agents/.skill-lock.json")
  for name in ${(f)skill_names}; do
    if [[ "${class}" == Work || ${work_skills[(Ie)${name}]} == 0 ]]; then
      skills_to_update+=("${name}")
    fi
  done
  result=0
  if (( ${#skills_to_update} )); then
    # The updater treats skills outside its discovery paths as missing and
    # reinstalls them even when their hashes match. Expose work snapshots only
    # for the update, then remove links or move updated snapshots back on exit.
    trap 'sync_work_skills' EXIT
    for name in "${skills_to_update[@]}"; do
      target="${work_dir}/${name}"
      source="${HOME}/.agents/skills/${name}"
      if [[ ${work_skills[(Ie)${name}]} != 0 && -d "${target}" && ! -e "${source}" && ! -L "${source}" ]]; then
        mkdir -p "${source:h}"
        ln -s "${target}" "${source}"
      fi
    done
    npx --yes skills update --global --yes "${skills_to_update[@]}" || result=$?
  fi
  exit "${result}"
fi
