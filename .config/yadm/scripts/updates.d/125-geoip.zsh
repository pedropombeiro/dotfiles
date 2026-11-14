#!/usr/bin/env zsh

step_geoip() {
  # 975-setup-geoip-credentials.sh hasn't run, or 1Password wasn't available
  [[ -s "${XDG_CONFIG_HOME:-$HOME/.config}/geoipupdate/license-key" ]] || return 0
  mise run geoip:update
}

_update_register "GeoLite2 database" step_geoip
