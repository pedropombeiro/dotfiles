#!/usr/bin/env zsh

# Verify that run-in-tmux-pane tracks its pane across windows, fails when the
# exit sentinel is missing, and propagates non-zero command exit statuses.
emulate -LR zsh
setopt err_exit
scripts=${0:A:h:h}
home_root=${scripts:h:h:h}
helper="$home_root/.agents/skills/run-in-tmux-pane/scripts/run-in-tmux-pane"
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox bash perl sleep
trap test_cleanup EXIT

test_stub tmux <<'SCRIPT'
#!/bin/sh
state_dir="${TMUX_TEST_STATE_DIR:?}"
mkdir -p "$state_dir"

case "$1" in
  split-window)
    pane_cmd=""
    for arg in "$@"; do
      pane_cmd="$arg"
    done
    case "${TMUX_TEST_MODE:-normal}" in
      missing_sentinel)
        tmpfile=$(printf '%s\n' "$pane_cmd" | sed -n "s/.*tee '\([^']*\)'.*/\1/p")
        printf 'partial output\n' > "$tmpfile"
        printf '%%99\n'
        ;;
      *)
        : > "$state_dir/pane.alive"
        (
          sh -c "$pane_cmd"
          rm -f "$state_dir/pane.alive"
        ) </dev/null >/dev/null 2>&1 &
        printf '%%99\n'
        ;;
    esac
    ;;
  list-panes)
    has_all=0
    for arg in "$@"; do
      if [ "$arg" = "-a" ]; then
        has_all=1
        break
      fi
    done
    # Active window only contains %1; the new pane %99 lives in another window.
    printf '%%1\n'
    if [ "$has_all" -eq 1 ] && [ -f "$state_dir/pane.alive" ]; then
      printf '%%99\n'
    fi
    ;;
  kill-pane)
    printf '%s\n' "$*" >> "$state_dir/kill-pane.log"
    rm -f "$state_dir/pane.alive"
    ;;
esac
SCRIPT

export TMUX='/tmp/tmux-test/default,123,0'
export TMUX_PANE='%42'
export TMUX_PANE_LINGER=0
export TMUX_TEST_STATE_DIR="$TEST_SANDBOX/tmux-state"

# Case 1: Target pane lives in another window from the active window.
# The helper must poll across windows (`list-panes -a`), wait for completion,
# return stdout and exit 0, and avoid calling kill-pane after normal exit.
rm -rf "$TEST_SANDBOX/tmux-state"
test_expect_status 'cross-window pane tracking' 0 "$helper" 'sleep 0.6; printf "cross-window ok\n"'
output=$(<"$TEST_SANDBOX/output")
test_assert_equal 'cross-window output' 'cross-window ok' "$output"
[[ ! -e "$TEST_SANDBOX/tmux-state/kill-pane.log" ]] || test_fail 'kill-pane should not run after normal pane exit'
print 'PASS: tracks pane across windows until completion'

# Case 2: Pane disappears before writing the exit sentinel.
# The helper must fail instead of defaulting to status 0, preserve partial
# output, and report the missing sentinel on stderr.
rm -rf "$TEST_SANDBOX/tmux-state"
TMUX_TEST_MODE=missing_sentinel test_expect_status 'missing exit sentinel' 1 "$helper" 'printf "ignored\n"'
output=$(<"$TEST_SANDBOX/output")
expected=$'partial output\nError: pane exited without exit sentinel'
test_assert_equal 'missing sentinel output' "$expected" "$output"
print 'PASS: fails when exit sentinel is missing'

# Case 3: Command exits with a non-zero status in the sentinel.
# The helper must return that exact status and full output.
rm -rf "$TEST_SANDBOX/tmux-state"
test_expect_status 'non-zero command exit' 7 "$helper" 'printf "failure detail\n"; (exit 7)'
output=$(<"$TEST_SANDBOX/output")
test_assert_equal 'non-zero output' 'failure detail' "$output"
print 'PASS: propagates non-zero exit status'
