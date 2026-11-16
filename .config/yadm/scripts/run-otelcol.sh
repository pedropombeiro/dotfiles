#!/bin/sh

# launchd supplies no shell/mise environment. Keep credentials out of arguments,
# generated config, and plists. Queue files may contain personal trace content.
set -eu
umask 077
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
export OTELCOL_STORAGE_DIR="$state_home/otelcol/queue"
mkdir -p "$OTELCOL_STORAGE_DIR"
chmod 700 "$state_home/otelcol" "$OTELCOL_STORAGE_DIR"

export OTELCOL_AUTHORIZATION=
credential="$config_home/opencode/otel-headers"
if [ -f "$credential" ]; then
  # This credential file is provisioned as one Authorization=Basic ... line.
  IFS= read -r header < "$credential" || [ -n "$header" ]
  case "$header" in
    'Authorization=Basic '*) OTELCOL_AUTHORIZATION=${header#Authorization=} ;;
    *) echo 'otelcol: expected Authorization=Basic ... in otel-headers' >&2; exit 1 ;;
  esac
fi

# A stable mise entry point follows the configured tool version after upgrades.
# Cap each launch's log history; launchd restarts the process if it fails.
log="$state_home/otelcol/collector.log"
if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 10485760 ]; then
  mv -f "$log" "$log.previous"
fi
exec mise exec -- otelcol-contrib --config "$config_home/otelcol/config.yaml" "$@" >> "$log" 2>&1
