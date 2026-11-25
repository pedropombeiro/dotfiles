#!/usr/bin/env zsh

# Verify op-ssh-sign-wrapper pass-through, pre-flight checks, and post-failure
# 1Password log classification.
emulate -LR zsh
setopt err_exit
scripts=${0:A:h:h}
home_root=${scripts:h:h:h}
wrapper="$home_root/.local/bin/op-ssh-sign-wrapper"
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox bash
trap test_cleanup EXIT

assert_contains() {
  local label=$1 needle=$2 haystack=$3
  if [[ $haystack != *"$needle"* ]]; then
    print -ru2 -- "FAIL: $label: expected output to contain: $needle"
    print -ru2 -- "Actual output:"
    print -ru2 -- "$haystack"
    exit 1
  fi
}

test_stub ioreg <<'SCRIPT'
#!/bin/sh
printf '<plist/>'
SCRIPT

test_stub plutil <<'SCRIPT'
#!/bin/sh
printf '%s\n' "${TEST_CONSOLE_LOCKED:-false}"
SCRIPT

test_stub ssh-add <<'SCRIPT'
#!/bin/sh
exit "${TEST_SSH_ADD_STATUS:-0}"
SCRIPT

test_stub fake-op-ssh-sign <<'SCRIPT'
#!/bin/sh
state_dir="${TEST_SIGN_STATE_DIR:?}"
mkdir -p "$state_dir"
printf '%s\n' "$*" >> "$state_dir/calls.log"
if [ -n "${TEST_APPEND_LOG:-}" ] && [ -n "${OP_LOG_FILE:-}" ]; then
  printf '%s\n' "$TEST_APPEND_LOG" >> "$OP_LOG_FILE"
fi
if [ "${TEST_SIGN_STATUS:-0}" -ne 0 ]; then
  printf '1Password: agent returned an error\n' >&2
fi
exit "${TEST_SIGN_STATUS:-0}"
SCRIPT

export OP_SSH_SIGN_BIN="$TEST_SANDBOX/bin/fake-op-ssh-sign"
export OP_SSH_AGENT_SOCK="$TEST_SANDBOX/agent.sock"
export OP_LOG_FILE="$TEST_SANDBOX/1Password_rCURRENT.log"
export TEST_SIGN_STATE_DIR="$TEST_SANDBOX/state"

reset_state() {
  rm -rf "$TEST_SIGN_STATE_DIR"
  mkdir -p "$TEST_SIGN_STATE_DIR"
  : > "$OP_SSH_AGENT_SOCK"
  printf 'INFO old log line\n' > "$OP_LOG_FILE"
}

# Case 1: Non-signing operations (-Y verify) pass straight through even if the
# screen is locked and the agent socket is missing.
reset_state
rm -f "$OP_SSH_AGENT_SOCK"
TEST_CONSOLE_LOCKED=true TEST_SSH_ADD_STATUS=2 TEST_SIGN_STATUS=0 \
  test_expect_status 'verify pass-through' 0 "$wrapper" -Y verify -n git -f allowed_signers
calls=$(<"$TEST_SIGN_STATE_DIR/calls.log")
test_assert_equal 'verify call args' '-Y verify -n git -f allowed_signers' "$calls"
print 'PASS: passes non-signing operations directly to op-ssh-sign'

# Case 2: Successful -Y sign when unlocked and agent is ready.
reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=0 \
  test_expect_status 'successful sign' 0 "$wrapper" -Y sign -n git -f pubkey payload
calls=$(<"$TEST_SIGN_STATE_DIR/calls.log")
test_assert_equal 'sign call args' '-Y sign -n git -f pubkey payload' "$calls"
print 'PASS: signs normally when unlocked and agent has keys'

# Case 3: Pre-flight fails fast when macOS screen is locked without invoking op-ssh-sign.
reset_state
TEST_CONSOLE_LOCKED=true TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=0 \
  test_expect_status 'screen locked preflight' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'screen locked reason' 'macOS screen is locked' "$output"
assert_contains 'screen locked guidance' 'Do not retry in run-in-tmux-pane' "$output"
[[ ! -e "$TEST_SIGN_STATE_DIR/calls.log" ]] || test_fail 'op-ssh-sign should not run when screen is locked'
print 'PASS: fails fast before op-ssh-sign when macOS screen is locked'

# Case 4: Pre-flight fails when agent socket is missing or ssh-add reports agent unavailable (exit 2).
reset_state
rm -f "$OP_SSH_AGENT_SOCK"
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 \
  test_expect_status 'missing agent socket' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'missing socket reason' 'socket is missing' "$output"
[[ ! -e "$TEST_SIGN_STATE_DIR/calls.log" ]] || test_fail 'op-ssh-sign should not run when socket is missing'

reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=2 \
  test_expect_status 'agent unavailable' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'agent unavailable reason' 'not responding' "$output"
[[ ! -e "$TEST_SIGN_STATE_DIR/calls.log" ]] || test_fail 'op-ssh-sign should not run when agent is unavailable'
print 'PASS: fails fast when 1Password SSH agent is missing or unavailable'

# Case 5: Pre-flight fails when ssh-add reports no identities loaded (exit 1).
reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=1 \
  test_expect_status 'no keys loaded' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'no keys reason' 'no SSH keys loaded' "$output"
[[ ! -e "$TEST_SIGN_STATE_DIR/calls.log" ]] || test_fail 'op-ssh-sign should not run when no keys are loaded'
print 'PASS: fails fast when 1Password SSH agent has no keys loaded'

# Case 6: Post-failure classification from 1Password_rCURRENT.log.
reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=1 \
  TEST_APPEND_LOG='WARN Suppressing Automated Unlock for 15s. Too many denied attempts in a short time period.' \
  test_expect_status 'rate limited classification' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'rate limited reason' 'rate-limited for 15s' "$output"

reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=1 \
  TEST_APPEND_LOG='INFO ssh authorization prompt timed out' \
  test_expect_status 'timeout classification' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'timeout reason' 'authorization prompt timed out' "$output"

reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=1 \
  TEST_APPEND_LOG='WARN AuthenticationFailed' \
  test_expect_status 'canceled classification' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'canceled reason' 'canceled or denied' "$output"

reset_state
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=1 \
  TEST_APPEND_LOG='WARN FailedToCreatePrivateKey' \
  test_expect_status 'secure enclave failure classification' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'secure enclave reason' 'macOS screen is locked' "$output"

# Ensure stale entries prior to the signing call are ignored.
reset_state
printf 'WARN Suppressing Automated Unlock for 15s.\n' >> "$OP_LOG_FILE"
TEST_CONSOLE_LOCKED=false TEST_SSH_ADD_STATUS=0 TEST_SIGN_STATUS=1 \
  TEST_APPEND_LOG='INFO failed to unlock app' \
  test_expect_status 'ignores stale log lines' 1 "$wrapper" -Y sign -n git -f pubkey payload
output=$(<"$TEST_SANDBOX/output")
assert_contains 'app locked reason' '1Password is locked' "$output"
print 'PASS: classifies post-failure 1Password logs and ignores stale lines'
