#!/usr/bin/env zsh

# Shared output and failure state for independently executed health checks.
YADM_SCRIPTS=${${(%):-%x}:A:h}
source "${YADM_SCRIPTS}/colors.sh"

function print_op() {
  printf "${CYAN}%s${NC}\n" "- $1"
}

function print_op_stay() {
  printf "${CYAN}%-63s${NC} " "- $1..."
}

function print_ok() {
  printf "${GREEN}%s${NC} %s\n" '✅ OK' "$1"
}

function print_failure() {
  [[ -n "${UPDATE_FAILURE_FILE:-}" ]] && print -r -- "$1" >> "${UPDATE_FAILURE_FILE}"
  printf "${RED}%s${NC}\n" "$1"
}

function print_warn() {
  printf "${YELLOW}%s${NC} %s\n" '⚠️  WARN' "$1"
}

any_failed=0
