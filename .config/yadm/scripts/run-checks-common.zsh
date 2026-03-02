#!/usr/bin/env zsh

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

any_failed=0

WAKATIME_CLI="$HOME/.wakatime/wakatime-cli"
if [[ -x "$WAKATIME_CLI" ]]; then
  print_op_stay "Checking wakatime-cli import_cfg points to base cfg"
  import_cfg=$(grep '^import_cfg' "$HOME/.wakatime.cfg" 2>/dev/null | sed 's/^import_cfg[[:space:]]*=[[:space:]]*//')
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
    "$WAKATIME_CLI" --entity "$1" --project-folder "$2" \
      --heartbeat-rate-limit-seconds 0 --disable-offline \
      --verbose --log-to-stdout 2>&1 \
      | grep 'sendHeartbeats' \
      | grep -o '\\"project\\":\\"[^\\]*\\"' \
      | head -1 \
      | sed 's/\\"project\\":\\"//;s/\\"//'
  }

  print_op_stay "Checking wakatime project detection for dotfiles"
  wakatime_project=$(wakatime_project_from_heartbeat "$HOME/.zshrc" "$HOME")
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
    test_repo=$(find "$HOME/Developer" -maxdepth 5 -name .git -type d 2>/dev/null | head -1 | sed 's|/\.git$||')
  fi
  if [[ -n "$test_repo" ]]; then
    wakatime_project=$(wakatime_project_from_heartbeat "$test_repo/README.md" "$test_repo")
    if [[ -n "$wakatime_project" && "$wakatime_project" != "dotfiles" ]]; then
      print_ok "$wakatime_project"
    else
      print_failure "Expected a non-dotfiles project name, got '${wakatime_project:-<empty>}'"
      any_failed=1
    fi
  else
    print_ok "(skipped, no test repo found)"
  fi
fi
