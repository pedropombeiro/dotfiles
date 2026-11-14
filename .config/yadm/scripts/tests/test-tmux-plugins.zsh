#!/usr/bin/env zsh

# Exercise the shared update step without contacting remotes or a tmux server.
emulate -LR zsh
setopt err_exit null_glob
scripts=${0:A:h:h}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/tmux-plugins-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
fail() { print -ru2 -- "FAIL: $*"; exit 1; }
export XDG_DATA_HOME="$sandbox/data with spaces"
export XDG_CONFIG_HOME="$sandbox/config with spaces"
export TMUX_TEST_LOG="$sandbox/commands"
mkdir -p "$sandbox/bin" "$XDG_DATA_HOME/tmux/plugins/tpm/bin"
export PATH="$sandbox/bin:$PATH"
for name in install_plugins update_plugins clean_plugins; do
  cat > "$XDG_DATA_HOME/tmux/plugins/tpm/bin/$name" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "${0##*/}${*:+ $*}" >> "$TMUX_TEST_LOG"
if [ "$TMUX_TEST_FAIL" = "${0##*/}" ]; then exit 7; fi
SCRIPT
done
cat > "$sandbox/bin/tmux" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "tmux $*" >> "$TMUX_TEST_LOG"
case "$1" in
  has-session) exit "${TMUX_TEST_SESSION_RC:-0}" ;;
  source-file) exit "${TMUX_TEST_RELOAD_RC:-0}" ;;
  *) exit 99 ;;
esac
SCRIPT
chmod +x "$sandbox/bin/tmux" "$XDG_DATA_HOME/tmux/plugins/tpm/bin/"*

run_step() {
  zsh -df -c '
    _update_watch() { :; }
    _update_register() { :; }
    source "$1/updates.d/115-tmux.zsh"
    step_tmux_plugins
  ' _ "$scripts"
}

expected=$'install_plugins\nupdate_plugins all\nclean_plugins\ntmux has-session'
run_step
[[ $(<"$TMUX_TEST_LOG") == "$expected"$'\n'"tmux source-file $XDG_CONFIG_HOME/tmux/tmux.conf" ]] || fail 'install/update/clean/reload order'
print 'PASS: newly installed plugins are initialized after updates'

: > "$TMUX_TEST_LOG"
TMUX_TEST_SESSION_RC=1 run_step
[[ $(<"$TMUX_TEST_LOG") == "$expected" ]] || fail 'reloaded without a session'
print 'PASS: no reload when no tmux session exists'

for name in install_plugins update_plugins clean_plugins; do
  : > "$TMUX_TEST_LOG"
  rc=0
  TMUX_TEST_FAIL=$name run_step || rc=$?
  (( rc == 7 )) || fail "$name failure status lost"
  log=$(<"$TMUX_TEST_LOG")
  lines=("${(@f)log}")
  [[ $log != *'tmux '* && $lines[-1] == "$name"* ]] || fail "continued after $name failed"
done
print 'PASS: TPM failures stop the step before reload'

rc=0
TMUX_TEST_RELOAD_RC=9 run_step || rc=$?
(( rc == 9 )) || fail 'reload failure status lost'
print 'PASS: reload failures are reported'
