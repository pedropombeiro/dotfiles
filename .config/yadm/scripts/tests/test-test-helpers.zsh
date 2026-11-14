#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit
scripts=${0:A:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox jq yadm rsync
trap test_cleanup EXIT

# An assertion failure must describe both sides without aborting this suite.
test_expect_status 'assertion diagnostics' 1 zsh -df -c '
  source "$1"
  TEST_SANDBOX=$2
  test_assert_equal "fixture ordering" "$3" "$4"
' _ "$scripts/tests/lib/test-helpers.zsh" "$TEST_SANDBOX" $'first\nsecond' $'second\nfirst'
grep -q 'fixture ordering' "$TEST_SANDBOX/output"
grep -q '^-first' "$TEST_SANDBOX/output"
grep -q '^+first' "$TEST_SANDBOX/output"

# Fake host settings must not reach an isolated suite or bypass its stubs.
mkdir -p "$TEST_SANDBOX/host/bin" "$TEST_SANDBOX/host/home"
cat > "$TEST_SANDBOX/host/bin/jq" <<'SCRIPT'
#!/bin/sh
echo 'host shim invoked' >&2
exit 99
SCRIPT
chmod +x "$TEST_SANDBOX/host/bin/jq"
# Model the actual shim path excluded by dependency resolution.
mkdir -p "$TEST_SANDBOX/host/mise"
ln -s ../bin "$TEST_SANDBOX/host/mise/shims"
print 'exit 98' > "$TEST_SANDBOX/host/home/.zshenv"
for suite in test-run-checks test-sync-work-skills; do
  test_expect_status "$suite with hostile environment" 0 env \
    HOME="$TEST_SANDBOX/host/home" ZDOTDIR="$TEST_SANDBOX/host/home" \
    XDG_CONFIG_HOME="$TEST_SANDBOX/host/home" GIT_DIR=/missing/repository \
    GIT_INDEX_FILE=/missing/index MISE_CONFIG_FILE=/missing/mise.toml \
    PATH="$TEST_SANDBOX/host/mise/shims:$PATH" \
    zsh -df "$scripts/tests/$suite.zsh"
done
[[ $(<"$TEST_SANDBOX/host/home/.zshenv") == 'exit 98' ]] || test_fail 'host file changed'
print 'PASS: sandbox isolation and assertion diffs'
