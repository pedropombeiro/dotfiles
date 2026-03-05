#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

GITIGNORE="${HOME}/.gitignore"
BEGIN_MARKER="# BEGIN yadm-alt (auto-generated, do not edit)"
END_MARKER="# END yadm-alt"

alt_basenames=$(yadm ls-files | grep -E '##' | sed 's/##.*//' | sort -u)

if [[ -z "${alt_basenames}" ]]; then
  return 0 2>/dev/null || exit 0
fi

alt_section="${BEGIN_MARKER}"
while IFS= read -r name; do
  alt_section+=$'\n'"${name}"
done <<<"${alt_basenames}"
alt_section+=$'\n'"${END_MARKER}"

if [[ -f "${GITIGNORE}" ]]; then
  if grep -qF "${BEGIN_MARKER}" "${GITIGNORE}"; then
    before=$(sed "/${BEGIN_MARKER//\//\\/}/,\$d" "${GITIGNORE}")
    after=$(sed "1,/${END_MARKER//\//\\/}/d" "${GITIGNORE}")
    printf '%s\n\n%s\n%s\n' "${before}" "${alt_section}" "${after}" >"${GITIGNORE}"
  else
    printf '\n%s\n' "${alt_section}" >>"${GITIGNORE}"
  fi
else
  printf '%s\n' "${alt_section}" >"${GITIGNORE}"
fi

count=$(echo "${alt_basenames}" | wc -l | tr -d ' ')
printf "${GREEN}%s${NC}\n" "Updated ${GITIGNORE} with ${count} yadm alt entries."
