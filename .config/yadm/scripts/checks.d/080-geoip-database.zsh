#!/usr/bin/env zsh

set -o pipefail
setopt EXTENDED_GLOB
source "${${(%):-%x}:A:h:h}/lib/check-helpers.zsh"

# The trip wrapper adds the GeoLite2 City database to trippy when it exists.
# The GeoLite2 license requires refreshing it at least every 30 days, which
# updates.d/125-geoip.zsh does on each dotfiles update.
function check_geoip_database() {
  print_op_stay "Checking the GeoLite2 City database is current"

  local db="${XDG_DATA_HOME:-$HOME/.local/share}/GeoIP/GeoLite2-City.mmdb"
  if [[ ! -s "$db" ]]; then
    echo
    print_warn "$db is missing; trippy runs without locations. Run ~/.config/yadm/bootstrap.d/975-setup-geoip-credentials.sh"
    return
  fi

  # (mh+719) matches a file modified 720 hours (30 days) ago or earlier, and (N)
  # yields nothing otherwise. MaxMind publishes twice a week, so each successful
  # update rewrites the file.
  local -a stale=($db(Nmh+719))
  if (( ${#stale} )); then
    echo
    print_warn "$db is over 30 days old, which the GeoLite2 license disallows. Run mise run geoip:update"
  else
    print_ok
  fi
}

check_geoip_database
exit "$any_failed"
