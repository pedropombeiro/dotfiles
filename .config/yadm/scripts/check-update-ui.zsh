#!/usr/bin/env zsh
# Exercise failure summaries without running updates or sending notifications.
emulate -LR zsh
setopt err_exit

YADM_SCRIPTS=${0:A:h}
source "${YADM_SCRIPTS}/update-ui.zsh"
local sandbox=$(mktemp -d "${TMPDIR:-/tmp}/update-ui-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
UPDATE_LOG="$sandbox/update.log"
_ui_total=5
_ui_tty=0
iterm2_progress() { :; }
iterm2_badge() { :; }
fail() { print -u2 -- "FAIL: $*"; exit 1; }

early_error() {
  print -u2 -- $'\e[31mError: Download failed on Cask whatsapp\e[0m'
  print -u2 -- 'curl: (92) HTTP/2 stream 1 reset by server'
  local -i i
  for i in {1..80}; do print -- "Successful output $i"; done
  print -- 'whatsapp was successfully upgraded!'
  return 1
}
_step brew early_error > "$sandbox/step"
[[ $_ui_failures[1] == 'brew (exit 1)' ]] || fail 'lost non-zero status'
[[ $_ui_failure_details[1] == *'Error: Download failed'* &&
   $_ui_failure_details[1] == *'curl: (92)'* ]] || fail 'lost early diagnostics'
[[ $_ui_failure_details[1] != *$'\e'* ]] || fail 'retained terminal colors'
_ui_print_summary > "$sandbox/summary"
[[ $(<"$sandbox/summary") == *'curl: (92)'* ]] || fail 'summary omitted cause'
[[ $(<"$sandbox/step") == *'earlier lines in the log'* ]] || fail 'fixture did not truncate output'
print 'PASS: early errors survive a successful-looking tail in the final summary'

explicit_failure() {
  print -- 'Specific explanation' > "$UPDATE_FAILURE_FILE"
  print -- 'Error: generic explanation'
  return 2
}
_step explicit explicit_failure > /dev/null
[[ $_ui_failure_details[2] == 'Specific explanation' ]] || fail 'overwrote explicit explanation'
print 'PASS: explicit failure details take precedence'

unknown_failure() {
  local -i i
  for i in {1..8}; do print -- "Unfamiliar diagnostic $i"; done
  print ''
  return 3
}
_step unknown unknown_failure > /dev/null
[[ $_ui_failure_details[3] == $'Unfamiliar diagnostic 4\nUnfamiliar diagnostic 5\nUnfamiliar diagnostic 6\nUnfamiliar diagnostic 7\nUnfamiliar diagnostic 8' ]] || fail 'wrong fallback tail'
print 'PASS: unfamiliar errors fall back to five non-blank lines'

many_errors() {
  local -i i
  for i in {1..12}; do print -- "fatal: problem $i"; done
  return 4
}
_step bounded many_errors > /dev/null
[[ $_ui_failure_details[4] == *'fatal: problem 8'* &&
   $_ui_failure_details[4] != *'fatal: problem 9'* &&
   $_ui_failure_details[4] == *'4 more error lines in the log'* ]] || fail 'unbounded diagnostics'
print 'PASS: error summaries are bounded'

successful_retry() { early_error || return 0; }
_step success successful_retry > /dev/null
(( ${#_ui_failures} == 4 )) || fail 'successful step was marked failed'
print 'PASS: successful steps do not acquire failure details'

local -i finish_rc=0
(
  _ui_snapshot() { :; }
  _ui_collect_caveats() { :; }
  _update_finish
) > /dev/null || finish_rc=$?
(( finish_rc == 1 )) || fail 'update did not retain failure exit status'
print 'PASS: the overall update still exits non-zero'
