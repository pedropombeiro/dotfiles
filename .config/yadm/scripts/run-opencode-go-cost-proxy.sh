#!/bin/sh

# launchd supplies no shell/mise environment. The proxy holds no credentials of
# its own and logs no headers, tokens, or prompt content.
set -eu
umask 077
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
log_dir="$state_home/opencode-go-cost-proxy"
mkdir -p "$log_dir"
chmod 700 "$log_dir"

# A stable mise entry point follows the configured tool version after upgrades.
# Cap each launch's log history; launchd restarts the process if it fails.
log="$log_dir/proxy.log"
if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 10485760 ]; then
  mv -f "$log" "$log.previous"
fi
exec mise exec -- node "$config_home/yadm/scripts/opencode-go-cost-proxy.mjs" "$@" >> "$log" 2>&1
