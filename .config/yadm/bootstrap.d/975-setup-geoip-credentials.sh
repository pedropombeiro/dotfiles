#!/usr/bin/env bash

set -euo pipefail

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/lib/colors.sh
source "${YADM_SCRIPTS}/lib/colors.sh"

# Caches the MaxMind account ID and license key that `mise run geoip:update`
# passes to geoipupdate, then downloads the GeoLite2 City database for trippy.
credentials_dir="${XDG_CONFIG_HOME:-$HOME/.config}/geoipupdate"
op_account_id="FAHP7RACSJGZFL7LH3MCW2TH4M"
op_vault_id="t66tzrlha6547px6nc4nfhpgym" # Private
op_item_title="MaxMind GeoLite2"

mkdir -p "${credentials_dir}"
umask 077

# setup_field FILE FIELD: copies one field of the 1Password item into FILE.
setup_field() {
  local target="${credentials_dir}/$1"
  local field=$2
  local tmp_file

  if [[ -s "${target}" ]]; then
    chmod 600 "${target}"
    return 0
  fi

  command -v op >/dev/null 2>&1 || return 1
  tmp_file=$(mktemp "${target}.XXXXXX")
  if op read --no-newline --account "${op_account_id}" \
    "op://${op_vault_id}/${op_item_title}/${field}" >"${tmp_file}" 2>/dev/null &&
    [[ -s "${tmp_file}" ]]; then
    mv "${tmp_file}" "${target}"
    chmod 600 "${target}"
    return 0
  fi
  rm -f "${tmp_file}"
  return 1
}

if ! setup_field account-id username || ! setup_field license-key password; then
  printf "${YELLOW}%s${NC}\n" "Could not read the '${op_item_title}' item from the Private 1Password vault."
  printf "${YELLOW}%s${NC}\n" "Write its username (account ID) to ${credentials_dir}/account-id and its password (license key) to ${credentials_dir}/license-key."
  printf "${YELLOW}%s${NC}\n" "Where 1Password isn't signed in, such as the NAS, copy them from a Mac: scp -r ~/.config/geoipupdate HOST:.config/"
  exit 0
fi

if mise run geoip:update; then
  printf "${GREEN}%s${NC}\n" "GeoLite2 City database is up to date"
else
  # A new license key returns HTTP 401 for a minute or two until MaxMind activates it
  printf "${YELLOW}%s${NC}\n" "Could not download the GeoLite2 City database. A new license key can take a few minutes to activate; retry with mise run geoip:update"
fi
