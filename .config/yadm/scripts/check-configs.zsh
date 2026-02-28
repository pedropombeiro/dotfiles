#!/usr/bin/env zsh

set -o pipefail

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

function print_op_stay() {
  printf "${CYAN}%-63s${NC} " "- $1..."
}

function print_ok() {
  printf "${GREEN}%s${NC}\n" '✅ OK'
}

function print_failure() {
  printf "${YELLOW}%s${NC}\n" "$1"
}

expected_files=(
  ~/.wakatime.cfg
)

any_missing=0

for expected_file in "${expected_files[@]}"; do
  print_op_stay "Checking for ${expected_file}"
  if [[ -f "${expected_file}" ]]; then
    print_ok
  else
    print_failure "Missing ${expected_file}"
    any_missing=1
  fi
done

if [[ ${any_missing} -eq 1 ]]; then
  printf "${YELLOW}%s${NC}\n" "⚠️  Missing expected config files."
else
  printf "${GREEN}%s${NC}\n" "✅ Config file checks passed!"
fi
