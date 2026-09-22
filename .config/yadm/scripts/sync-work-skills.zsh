#!/usr/bin/env zsh

set -eu

class=$(yadm config local.class || true)
work_dir="${HOME}/.agents/skills.work"
typeset -a work_skills=(
  caproni clickhouse-best-practices fpf-report gitlab-babysit-mr
  gitlab-pipeline-watch glab-glql orbit incident
)

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
      elif [[ "${name}" == clickhouse-best-practices && -d "${target}" && ! -L "${target}" ]]; then
        # The upstream installer recreates this snapshot in the shared directory.
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
    npx --yes skills update --global --yes "${skills_to_update[@]}" || result=$?
  fi
  sync_work_skills
  exit "${result}"
fi
