#!/bin/sh

# Restarts the Go cost proxy when it stops answering.
#
# launchd keeps the proxy running, but a process that is alive and no longer
# serving stays alive, and OpenCode reaches the provider only through the
# proxy. Two failed probes in a row mean the proxy is stuck, so it is
# restarted. One failed probe is not enough, because the proxy needs a moment
# to come up after a restart.

set -eu
umask 077

label="dev.mise.opencode-go-cost-proxy"
port=${OPENCODE_GO_PROXY_PORT:-47990}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
log_dir="$state_home/opencode-go-cost-proxy"
mkdir -p "$log_dir"
chmod 700 "$log_dir"

log="$log_dir/watchdog.log"
failures_file="$log_dir/watchdog-failures"

if curl -fsS --max-time 5 "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1; then
  rm -f "$failures_file"
  exit 0
fi

failures=0
if [ -f "$failures_file" ]; then
  failures=$(cat "$failures_file")
fi
failures=$((failures + 1))
printf '%s\n' "$failures" > "$failures_file"

if [ "$failures" -lt 2 ]; then
  exit 0
fi

rm -f "$failures_file"
printf '%s the proxy did not answer %s times, restarting it\n' "$(date -u +%FT%TZ)" "$failures" >> "$log"
launchctl kickstart -k "gui/$(id -u)/$label" >> "$log" 2>&1
