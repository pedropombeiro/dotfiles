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
  list-clients) printf '%s\t%s\t%s\n' '$tty' '%1' '\$1' ;;
  display-message)
    case "\$5" in
      '#{@opencode-attention}') cat '$TEST_SANDBOX/attention' 2>/dev/null ;;
      *) printf 'build; \033[31mdeploy\001\177\n' ;;
    esac ;;
  list-panes)
    [ "\$2" = '-s' ] && [ "\$3" = '-t' ] && [ "\$4" = '\$1' ] || exit 1
    cat '$TEST_SANDBOX/session-attention' 2>/dev/null ;;
esac
SCRIPT
print -rn '' > "$TEST_SANDBOX/attention"
print -rn '' > "$TEST_SANDBOX/session-attention"
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
expected=$'\033]21337;status=build, [31mdeploy;status-color=;indicator=\007'
received=${received//$'\r'/}
# Compare quoted forms so a failure shows the control characters.
test_assert_equal 'subtitle sequence' "${(q+)expected}" "${(q+)received}"
print 'PASS: subtitles reach readable terminals'

check_colors() {
  local label=$1 pane_state=$2 session_states=$3 color=$4 indicator=$5
  print -rn -- "$pane_state" > "$TEST_SANDBOX/attention"
  print -r -- "$session_states" > "$TEST_SANDBOX/session-attention"
  test_expect_status "$label" 0 "$subtitle"
  local received= chunk expected
  repeat 20; do
    zpty -r -t readable chunk 2>/dev/null && received+=$chunk
    [[ $received == *$'\007'* ]] && break
    sleep 0.1
  done
  received=${received//$'\r'/}
  expected=$'\033]21337;status=build, [31mdeploy;status-color='"$color;indicator=$indicator"$'\007'
  test_assert_equal "$label" "${(q+)expected}" "${(q+)received}"
}
check_colors 'waiting pane' waiting waiting '#ff9f0a' '#ff9f0a'
check_colors 'failed pane' error error '#ff453a' '#ff453a'
check_colors 'background waiting outranks active error' error $'error\nwaiting' '#ff453a' '#ff9f0a'
check_colors 'background failure, neutral active pane' '' $'\nerror' '' '#ff453a'
check_colors 'waiting remains higher priority in either order' '' $'waiting\nerror' '' '#ff9f0a'
check_colors 'unknown pane state cannot inject colors' 'error;indicator=#ffffff' '' '' ''
check_colors 'clear resolved attention' '' '' '' ''
test_expect_status 'detach clear' 0 "$subtitle" --clear "$tty"
received=
repeat 20; do
  zpty -r -t readable chunk 2>/dev/null && received+=$chunk
  [[ $received == *$'\007'* ]] && break
  sleep 0.1
done
received=${received//$'\r'/}
expected=$'\033]21337;status=;status-color=;indicator=\007'
test_assert_equal 'detach clears text and colors' "${(q+)expected}" "${(q+)received}"
print 'PASS: active-pane colors, session-wide dot priority, sanitization, and detach clearing'

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
