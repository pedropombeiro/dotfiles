#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit pipe_fail
scripts=${0:A:h:h}
import_script=${scripts:h}/bootstrap.d/942-import-raycast-settings.sh##os.Darwin
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox bash python3 mkdir shasum cut touch cat rm
trap test_cleanup EXIT
unset RAYCAST_FORCE_IMPORT
export RAYCAST_TEST_LOG="$TEST_SANDBOX/open.log"
export RAYCAST_TEST_APP=0 RAYCAST_TEST_OPEN=0
test_stub osascript <<'SH'
#!/bin/sh
exit "$RAYCAST_TEST_APP"
SH
test_stub open <<'SH'
#!/bin/sh
printf '%s\n' "$@" >> "$RAYCAST_TEST_LOG"
exit "$RAYCAST_TEST_OPEN"
SH

# Supply a terminal only to the fixture process, never to the real Raycast app.
run_interactive() {
  python3 - "$import_script" "$1" <<'PY'
import os
import pty
import subprocess
import sys

master, slave = pty.openpty()
try:
    os.write(master, sys.argv[2].encode())
    result = subprocess.run(["bash", sys.argv[1]], stdin=slave)
finally:
    os.close(slave)
    os.close(master)
sys.exit(result.returncode)
PY
}

marker="$XDG_STATE_HOME/yadm/raycast-imported.sha256"
backups="$HOME/Sync/pedro/Briefcase/Backups/raycast"
test_expect_status 'missing backups' 0 bash "$import_script"
[[ ! -e $RAYCAST_TEST_LOG ]] || test_fail 'opened without a backup'
mkdir -p "$backups"
old="$backups/Z older.rayconfig"
latest="$backups/A latest.rayconfig"
print old > "$old"
print latest > "$latest"
touch -t 202601010000 "$old"
touch -t 202602010000 "$latest"
mkdir "$backups/not-a-file.rayconfig"

test_expect_status 'noninteractive run' 0 bash "$import_script"
[[ ! -e $RAYCAST_TEST_LOG && ! -e $marker ]] || test_fail 'noninteractive run changed state'
export RAYCAST_TEST_APP=1
test_expect_status 'missing app' 0 run_interactive $'y\ny\n'
[[ ! -e $RAYCAST_TEST_LOG ]] || test_fail 'opened missing app'
export RAYCAST_TEST_APP=0
test_expect_status 'decline import' 0 run_interactive $'n\n'
[[ ! -e $RAYCAST_TEST_LOG ]] || test_fail 'opened declined import'
test_expect_status 'unconfirmed import' 0 run_interactive $'y\nn\n'
test_assert_equal 'newest file and arguments' $'-a\nRaycast\n'"$latest" "$(cat "$RAYCAST_TEST_LOG")"
[[ ! -e $marker ]] || test_fail 'recorded an unconfirmed import'
rm "$RAYCAST_TEST_LOG"

export RAYCAST_TEST_OPEN=1
test_expect_status 'failed launch' 1 run_interactive $'y\ny\n'
[[ ! -e $marker ]] || test_fail 'recorded failed launch'
export RAYCAST_TEST_OPEN=0
rm "$RAYCAST_TEST_LOG"
test_expect_status 'confirmed import' 0 run_interactive $'yes\nyes\n'
expected_hash=$(shasum -a 256 "$latest" | cut -d' ' -f1)
test_assert_equal 'confirmed hash' "$expected_hash" "$(cat "$marker")"
rm "$RAYCAST_TEST_LOG"
test_expect_status 'already imported' 0 run_interactive $'y\ny\n'
[[ ! -e $RAYCAST_TEST_LOG ]] || test_fail 'reopened confirmed backup'

export RAYCAST_FORCE_IMPORT=1
test_expect_status 'forced import' 0 run_interactive $'y\ny\n'
[[ -e $RAYCAST_TEST_LOG ]] || test_fail 'force did not reopen backup'
unset RAYCAST_FORCE_IMPORT
rm "$RAYCAST_TEST_LOG"
print changed >> "$latest"
test_expect_status 'updated backup' 0 run_interactive $'y\ny\n'
expected_hash=$(shasum -a 256 "$latest" | cut -d' ' -f1)
test_assert_equal 'updated hash' "$expected_hash" "$(cat "$marker")"
print 'PASS: Raycast backup discovery, confirmation, repeat safety, and failures'
