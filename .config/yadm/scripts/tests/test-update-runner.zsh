#!/usr/bin/env zsh

# Registration and execution fixtures never invoke production update steps.
emulate -LR zsh
setopt err_exit null_glob
scripts=${0:A:h:h}
[[ -f "$scripts/update.zsh" && ! -L "$scripts/update.zsh" ]] || {
  print -ru2 -- 'FAIL: update.zsh must be an ordinary executable entry point'
  exit 1
}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/update-runner-test.XXXXXXXX")
sandbox=${sandbox:A}
trap 'rm -rf -- "$sandbox"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=yadm.auto-alt GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=yadm.auto-perms GIT_CONFIG_VALUE_1=false
fail() { print -ru2 -- "FAIL: $*"; exit 1; }
source "$scripts/lib/update-runner.zsh"
mkdir -p "$sandbox/modules"
if _update_load_modules "$sandbox/modules" 2> "$sandbox/error"; then
  fail 'empty directory accepted'
fi
cat > "$sandbox/modules/010-first.zsh" <<'MODULE'
first() { shared_state=ready; _update_note 'shared state set'; }
_update_watch mise npm
_update_register first first
MODULE
cat > "$sandbox/modules/020-second.zsh##os.Darwin" <<'MODULE'
second() { [[ $shared_state == ready ]] || return 8; _update_warn 'nonfatal warning'; }
_update_watch npm brew
_update_use_sudo
_update_register --interactive second second
MODULE
ln -s '020-second.zsh##os.Darwin' "$sandbox/modules/020-second.zsh"
print 'return 99' > "$sandbox/modules/030-inactive.zsh##os.Linux"
print 'return 99' > "$sandbox/modules/.hidden.zsh"
mkdir -p "$sandbox/modules/nested"
print 'return 99' > "$sandbox/modules/nested/040-nested.zsh"
chmod +x "$sandbox/modules/"*.zsh*
_update_load_modules "$sandbox/modules"
[[ ${(j:,:)_update_labels} == first,second ]] || fail 'wrong registration order'
[[ ${(j:,:)_update_managers} == mise,npm,brew ]] || fail 'manager order/deduplication'
[[ -z $shared_state && $_update_sudo == 1 ]] || fail 'live work during registration'
if _update_register duplicate first 2> "$sandbox/error"; then fail 'duplicate accepted'; fi
if _update_register missing undefined 2> "$sandbox/error"; then fail 'undefined function accepted'; fi
ln -s missing "$sandbox/modules/005-broken.zsh"
if (_update_load_modules "$sandbox/modules") 2> "$sandbox/error"; then fail 'broken link accepted'; fi
rm "$sandbox/modules/005-broken.zsh"
chmod -x "$sandbox/modules/010-first.zsh"
if (_update_load_modules "$sandbox/modules") 2> "$sandbox/error"; then fail 'disabled module accepted'; fi
chmod +x "$sandbox/modules/010-first.zsh"
print 'if then' > "$sandbox/modules/005-syntax.zsh"
chmod +x "$sandbox/modules/005-syntax.zsh"
if (_update_load_modules "$sandbox/modules") 2> "$sandbox/error"; then fail 'syntax error accepted'; fi
rm "$sandbox/modules/005-syntax.zsh"
print '_update_register missing undefined; print should-not-run' > "$sandbox/modules/005-registration.zsh"
chmod +x "$sandbox/modules/005-registration.zsh"
if (_update_load_modules "$sandbox/modules") > "$sandbox/output" 2> "$sandbox/error"; then
  fail 'failed registration accepted'
fi
[[ ! -s "$sandbox/output" ]] || fail 'registration failure did not stop module'
rm "$sandbox/modules/005-registration.zsh"
print 'PASS: discovery, validation, registration, and deferred execution'

source "$scripts/lib/update-ui.zsh"
trap 'rm -rf -- "$sandbox"' EXIT
UPDATE_LOG="$sandbox/update.log"
_ui_log_dir="$sandbox/logs"
PROGRESS_OFFSET=25 PROGRESS_RANGE=50
_ui_progress_offset=25 _ui_progress_range=50
iterm2_progress() { print -r -- "$*" >> "$sandbox/progress"; }
iterm2_badge() { :; }
iterm2_notify() { :; }
_update_require_sudo() { print sudo >> "$sandbox/lifecycle"; }
_update_track() { print -r -- "track:$*" >> "$sandbox/lifecycle"; }
_ui_snapshot() { :; }
_ui_collect_caveats() { :; }
broken() { print 'fixture detail' > "$UPDATE_FAILURE_FILE"; false; print should-not-run; }
last() { [[ $shared_state == ready ]]; print last >> "$sandbox/lifecycle"; }
_update_register broken broken
_update_register last last
rc=0
(
  _update_execute
) > "$sandbox/output" 2>&1 || rc=$?
(( rc == 1 )) || fail 'failure exit status lost'
output=$(<"$sandbox/output")
[[ $output == *'[4/4]'* && $output == *'fixture detail'* && $output != *should-not-run* ]] || fail 'count or failure handling'
[[ $output == *'nonfatal warning'* && $output == *'shared state set'* ]] || fail 'warnings or notes lost'
[[ $(<"$sandbox/lifecycle") == $'sudo\ntrack:mise npm brew\nlast' ]] || fail 'lifecycle or failure continuation'
[[ $(<"$sandbox/progress") == $'25\n25\n37\n50\n62' ]] || fail 'NAS progress mapping'
[[ ! -d $_ui_snapshot_dir || -z $_ui_snapshot_dir ]] || fail 'snapshot cleanup'
[[ $output == *'▶ [2/4] second'* ]] || fail 'interactive mode lost'
print 'PASS: shared state, progress, interactive steps, diagnostics, and continuation'

# A fresh shell exercises real EXIT traps (parenthesized Zsh subshells do not).
rc=0
PROGRESS_OFFSET=25 PROGRESS_RANGE=50 zsh -f -c '
  source "$1/lib/update-ui.zsh"
  _ui_log_dir="$2/cleanup-logs"
  iterm2_progress() { print -r -- "$*" >> "${_ui_log_dir}/progress"; }
  iterm2_badge() { :; }
  iterm2_notify() { :; }
  _ui_snapshot() { :; }
  _ui_collect_caveats() { :; }
  _update_init 1
  print -r -- "$_ui_snapshot_dir" > "$2/snapshot-path"
  fail_step() { return 3; }
  _step fixture fail_step
  _update_finish
' _ "$scripts" "$sandbox" > "$sandbox/cleanup-output" 2>&1 || rc=$?
[[ $rc == 1 && ! -d $(<"$sandbox/snapshot-path") ]] || fail 'EXIT cleanup or failure status'
[[ $(<"$sandbox/cleanup-logs/progress") == $'25\n25\n-e' ]] || fail "failure progress cleanup: $(<"$sandbox/cleanup-logs/progress")"
print 'PASS: EXIT cleanup and NAS failure progress'

zsh -f -c '
  source "$1/lib/update-ui.zsh"
  _ui_log_dir="$2/success-logs"
  iterm2_progress() { print -r -- "$*" >> "${_ui_log_dir}/progress"; }
  iterm2_badge() { :; }
  iterm2_notify() { :; }
  _ui_snapshot() { :; }
  _ui_collect_caveats() { :; }
  unset PROGRESS_OFFSET
  _update_init 1
  print -r -- "$_ui_snapshot_dir" > "$2/success-snapshot"
  _update_finish
' _ "$scripts" "$sandbox" > "$sandbox/success-output" 2>&1
[[ ! -d $(<"$sandbox/success-snapshot") ]] || fail 'success cleanup'
[[ $(<"$sandbox/success-logs/progress") == $'-i\n100\n-c' ]] || fail 'success progress cleanup'
print 'PASS: successful completion and cleanup'

# Exercise the public entry point with fixture modules and a fake UI only.
mkdir -p "$sandbox/entry/lib" "$sandbox/entry/updates.d"
cp "$scripts/update.zsh" "$sandbox/entry/"
cp "$scripts/lib/update-runner.zsh" "$sandbox/entry/lib/"
cp "$sandbox/modules/010-first.zsh" "$sandbox/entry/updates.d/"
cat > "$sandbox/entry/lib/update-ui.zsh" <<'UI'
_update_init() { print -r -- "count:$1"; }
_update_track() { :; }
_update_note() { :; }
_step() { "$2"; }
_update_finish() { [[ $shared_state == ready ]]; }
UI
[[ $(zsh -df "$sandbox/entry/update.zsh") == count:1 ]] || fail 'public entry point'
print 'PASS: public update entry point'

# Select actual production alternates, then inspect registrations without execution.
mkdir -p "$sandbox/identity/updates.d" "$sandbox/identity/lib"
cp "$scripts/updates.d/"*.zsh*(N-.) "$sandbox/identity/updates.d/"
cp "$scripts/lib/startup-benchmark.zsh" "$sandbox/identity/lib/"
yd() { yadm --yadm-dir "$sandbox/yadm-config" --yadm-data "$sandbox/yadm-data" "$@"; }
yd init -w "$sandbox/identity" > "$sandbox/yadm-output" 2>&1
yd add "$sandbox/identity/updates.d" >> "$sandbox/yadm-output" 2>&1
common=$'tldr\nzinit\nzsh bytecode\nbat theme\nnpm\nopencode skills\nopencode telemetry\nskill repositories\nzsh benchmark\nyazi plugins\ngit hooks\nneovim plugins\nneovim benchmark\nconfig checks'
for identity in Darwin:Personal Darwin:Work Linux:Personal Linux:Work Linux:NAS:qts; do
  parts=("${(@s/:/)identity}")
  yd config local.os "$parts[1]"
  yd config local.class "$parts[2]"
  yd config local.distro "${parts[3]:-test}"
  for link in "$sandbox/identity/updates.d/"*.zsh(@); do rm "$link"; done
  yd alt > "$sandbox/yadm-output" 2>&1
  expected=$common
  case $identity in
    Darwin:*)
      expected=$'relink dotfiles\nbrew\napprove downloads\ntmux signature\nmise bootstrap\nmac app store\nmise tools\n'"$common"
      [[ $identity != Darwin:Work ]] || expected+=$'\ngitlab dotfiles\nwork skill repos\ngdk config\nchecks'
      expected+=$'\nbrew dump'
      ;;
    Linux:Personal) expected=$'apt\nbrew\n'"$common" ;;
    Linux:NAS:qts) expected=$'entware\nmise\ngrc-rs rules\ntmux plugins\ncontainer hk hooks\n'"$common" ;;
  esac
  actual=$(zsh -f -c '
    YADM_SCRIPTS=$1
    source "$2/lib/update-runner.zsh"
    _update_load_modules "$1/updates.d" || exit 1
    print -rl -- "${_update_labels[@]}"
  ' _ "$sandbox/identity" "$scripts")
  [[ $actual == "$expected" ]] || fail "$identity selection/order: $actual"
  case $identity in
    Darwin:*) expected_managers='brew cask mise npm mas nvim mason zinit skills' ;;
    Linux:Personal) expected_managers='apt brew mise npm nvim mason zinit skills' ;;
    Linux:NAS:qts) expected_managers='opkg mise npm nvim mason zinit skills' ;;
    *) expected_managers='zinit skills' ;;
  esac
  actual_managers=$(zsh -f -c '
    YADM_SCRIPTS=$1
    source "$2/lib/update-runner.zsh"
    _update_load_modules "$1/updates.d" || exit 1
    print -r -- "${(j: :)_update_managers}"
  ' _ "$sandbox/identity" "$scripts")
  [[ $actual_managers == "$expected_managers" ]] || fail "$identity package tracking"
  print -r -- "PASS: $identity update selection and step order"
done
