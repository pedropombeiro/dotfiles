#!/usr/bin/env zsh

emulate -LR zsh
setopt errexit pipefail
scripts=${0:A:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
runner=$scripts/run-otelcol.sh
config=$scripts/../../otelcol/config.yaml
test_sandbox sh chmod mkdir wc mv python3
trap test_cleanup EXIT

mkdir -p "$XDG_CONFIG_HOME/opencode" "$XDG_CONFIG_HOME/otelcol"
cp "$config" "$XDG_CONFIG_HOME/otelcol/config.yaml"
test_stub mise <<'SH'
#!/bin/sh
printf '%s\n' "$OTELCOL_AUTHORIZATION" > "$XDG_STATE_HOME/auth"
printf '%s\n' "$OTELCOL_STORAGE_DIR" > "$XDG_STATE_HOME/storage"
printf '%s\n' "$@" > "$XDG_STATE_HOME/args"
SH

test_expect_status 'LAN credential optional' 0 sh "$runner"
test_assert_equal 'empty LAN auth' '' "$(cat "$XDG_STATE_HOME/auth")"
test_assert_equal 'private state location' "$XDG_STATE_HOME/otelcol/queue" "$(cat "$XDG_STATE_HOME/storage")"
test_assert_equal 'collector arguments' "$(printf '%s\n' exec -- otelcol-contrib --config "$XDG_CONFIG_HOME/otelcol/config.yaml")" "$(cat "$XDG_STATE_HOME/args")"
print -rn -- 'Authorization=Basic dGVzdDpwYXNz==' > "$XDG_CONFIG_HOME/opencode/otel-headers"
test_expect_status 'credential without final newline' 0 sh "$runner"
test_assert_equal 'Basic value preserved' 'Basic dGVzdDpwYXNz==' "$(cat "$XDG_STATE_HOME/auth")"
print -r -- 'invalid-header' > "$XDG_CONFIG_HOME/opencode/otel-headers"
test_expect_status 'reject malformed credential' 1 sh "$runner"

python3 - "$XDG_STATE_HOME/otelcol" <<'PY'
import os
import stat
import sys
from pathlib import Path

state = Path(sys.argv[1])
for path in (state, state / 'queue', state / 'collector.log'):
    assert stat.S_IMODE(path.stat().st_mode) & 0o077 == 0, path
PY
print 'PASS: relay launcher, credentials, paths, and permissions'
