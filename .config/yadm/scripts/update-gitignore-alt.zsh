#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )" &>/dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

GITIGNORE="${HOME}/.gitignore"
BEGIN_MARKER="# BEGIN yadm-alt (auto-generated, do not edit)"
END_MARKER="# END yadm-alt"

# (f) splits on newlines, (M) keeps only matching elements, (u) deduplicates, (o) sorts
local -a alt_lines=( "${(@fo)$(yadm ls-files)}" )
alt_lines=( ${(M)alt_lines:#*\#\#*} )
# Strip ##... suffix from each element and deduplicate+sort
local -a alt_basenames=( "${(@ou)alt_lines/\#\#*/}" )

if (( ${#alt_basenames} == 0 )); then
  return 0 2>/dev/null || exit 0
fi

alt_section="${BEGIN_MARKER}"
for name in "${alt_basenames[@]}"; do
  alt_section+=$'\n'"${name}"
done
alt_section+=$'\n'"${END_MARKER}"

if [[ -f "${GITIGNORE}" ]]; then
  local content=$(<"${GITIGNORE}")
  if [[ "${content}" == *"${BEGIN_MARKER}"* ]]; then
    local before=${content%%${BEGIN_MARKER}*}
    local after=${content#*${END_MARKER}}
    # Strip trailing/leading newlines at the seam
    before=${before%$'\n'}
    after=${after#$'\n'}
    printf '%s\n\n%s\n%s\n' "${before}" "${alt_section}" "${after}" >"${GITIGNORE}"
  else
    printf '\n%s\n' "${alt_section}" >>"${GITIGNORE}"
  fi
else
  printf '%s\n' "${alt_section}" >"${GITIGNORE}"
fi

printf "${GREEN}%s${NC}\n" "Updated ${GITIGNORE} with ${#alt_basenames} yadm alt entries."
