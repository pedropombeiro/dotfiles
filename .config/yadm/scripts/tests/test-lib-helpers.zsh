#!/usr/bin/env zsh

# Exercise library loading and legacy NAS paths without live operations.
emulate -LR zsh
setopt err_exit

scripts=${0:A:h:h}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/lib-helpers-test.XXXXXXXX")
sandbox=${sandbox:A}
trap 'rm -rf -- "$sandbox"' EXIT
root="$sandbox/home/.config/yadm/scripts"
mkdir -p "$root/lib"
cp "$scripts/colors.sh" "$scripts/iterm2.sh" "$root/"
cp "$scripts/lib/"{colors.sh,iterm2.sh,check-helpers.zsh,update-ui.zsh,update-packages.zsh,wait-for.sh} "$root/lib/"

for shell in sh bash zsh; do
  HOME="$sandbox/home" "$shell" -c '
    set -eu
    cd /
    . "$HOME/.config/yadm/scripts/colors.sh"
    . "$HOME/.config/yadm/scripts/iterm2.sh"
    [ -n "$GREEN" ]
    command -v iterm2_progress >/dev/null
    command -v iterm2_badge >/dev/null
    command -v iterm2_notify >/dev/null
  '
  print -r -- "PASS: legacy NAS helper paths in $shell"
done

bash -c 'source "$1/lib/wait-for.sh"; declare -F wait_for >/dev/null' _ "$root"
zsh -f -c '
  source "$1/lib/check-helpers.zsh"
  [[ $YADM_SCRIPTS == "$1" && $any_failed == 0 && -n $GREEN ]] || exit 1
' _ "$root"
zsh -f -c '
  YADM_SCRIPTS=$1
  source "$1/lib/update-ui.zsh"
  [[ $YADM_SCRIPTS == "$1" ]] || exit 1
  (( $+functions[_update_init] ))
' _ "$root"
print 'PASS: library dependencies and scripts-root resolution'
