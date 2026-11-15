#!/usr/bin/env zsh

# Reproduce a tmux client whose terminal stops reading output, such as an SSH
# session orphaned by a closed iTerm2 tab, and check that subtitle writes
# give up instead of blocking tmux hooks and config reloads.
emulate -LR zsh
setopt err_exit
scripts=${0:A:h:h}
subtitle=${scripts:h:h}/tmux/iterm2-subtitle
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox bash sleep tr
zmodload zsh/zpty zsh/datetime
filler=
cleanup() {
  [[ -n $filler ]] && kill -KILL "$filler" 2>/dev/null
  zpty -d 2>/dev/null
  test_cleanup
}
trap cleanup EXIT

# Start a pseudo-terminal and record its device path. Each test reads it or not.
open_tty() {
  local name=$1 file="$TEST_SANDBOX/$1.tty"
  zpty "$name" "tty > ${(q)file}; exec sleep 60"
  repeat 50; do [[ -s $file ]] && break; sleep 0.1; done
  [[ -s $file ]] || test_fail "$name: pseudo-terminal did not start"
  REPLY=$(<"$file")
}

# A readable terminal receives the escape sequence with control characters
# removed and semicolons replaced, so a title can't inject OSC fields or escape
# codes. The title includes ESC and DEL, which BusyBox tr once let through.
open_tty readable
tty=$REPLY
test_stub tmux <<SCRIPT
#!/bin/sh
case "\$1" in
  list-clients) printf '%s\t%s\n' '$tty' '%1' ;;
  display-message) printf 'build; \033[31mdeploy\001\177\n' ;;
esac
SCRIPT
start=$EPOCHREALTIME
ITERM2_SUBTITLE_WRITE_TIMEOUT=3 test_expect_status 'readable terminal' 0 "$subtitle"
elapsed=$(( EPOCHREALTIME - start ))
# A completed write must stop the watchdog instead of waiting out the timeout.
(( elapsed < 2 )) || test_fail "readable terminal: took ${elapsed}s, expected the watchdog to stop"
# Assign before comparing: zsh -n still reads $(<file) in a command argument.
output=$(<"$TEST_SANDBOX/output")
test_assert_equal 'no script output' '' "$output"
received=
repeat 20; do
  zpty -r -t readable chunk 2>/dev/null && received+=$chunk
  [[ $received == *$'\007'* ]] && break
  sleep 0.1
done
expected=$'\033]21337;status=build, [31mdeploy\007'
received=${received//$'\r'/}
# Compare quoted forms so a failure shows the control characters.
test_assert_equal 'subtitle sequence' "${(q+)expected}" "${(q+)received}"
print 'PASS: subtitles reach readable terminals'

# Fill an unread terminal's output buffer. The filler blocks once it is full.
open_tty unread
tty=$REPLY
{ while :; do printf '%01024d' 0; done > "$tty"; } 2>/dev/null &
filler=$!
sleep 1
start=$EPOCHREALTIME
ITERM2_SUBTITLE_WRITE_TIMEOUT=1 test_expect_status 'unread terminal' 0 "$subtitle" --clear "$tty"
elapsed=$(( EPOCHREALTIME - start ))
# Returning well before the timeout means the writer was killed without waiting.
(( elapsed >= 0.9 && elapsed < 5 )) || test_fail "unread terminal: took ${elapsed}s, expected about 1s"
output=$(<"$TEST_SANDBOX/output")
test_assert_equal 'no kill notice' '' "$output"
print 'PASS: writes to unread terminals time out silently'
