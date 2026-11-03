#!/usr/bin/env bash
#
# Sync Hex (https://anoma.ly/hex) settings with ~/.config/yadm/hex-settings.json.
#
#   apply  Start Hex, apply the tracked settings and vocabulary, and save a snapshot.
#   dump   Add the settings changed since the snapshot, and the current vocabulary,
#          to the tracked file.
#
# Hex replaces settings.json on every save and mixes it with machine state, so the
# tracked file holds only overrides. Hex doesn't report its defaults, so dump finds
# overrides by comparing against the snapshot that apply or the last dump saved.

set -euo pipefail

tracked="${HOME}/.config/yadm/hex-settings.json"
snapshot="${XDG_STATE_HOME:-${HOME}/.local/state}/yadm/hex-settings.snapshot.json"
# Device names differ between machines; Hex falls back to the system default.
excluded='["microphone"]'

hex_bin() {
  if command -v hex &>/dev/null; then
    command -v hex
  elif [[ -x /Applications/Hex.app/Contents/MacOS/hex ]]; then
    echo /Applications/Hex.app/Contents/MacOS/hex
  fi
}

current_settings() {
  "${hex}" settings list --json |
    jq -S '[.settings[] | select(.writable and .available) | {(.key): .value}] | add // {}'
}

save_snapshot() {
  mkdir -p "${snapshot%/*}"
  current_settings >"${snapshot}.tmp"
  mv "${snapshot}.tmp" "${snapshot}"
}

apply() {
  "${hex}" start >/dev/null

  if [[ -f ${tracked} ]]; then
    if jq -e '.settings // {} | length > 0' "${tracked}" >/dev/null; then
      jq '.settings' "${tracked}" | "${hex}" settings apply -
    fi
    # `vocabulary add` merges, so terms added only on this machine stay.
    jq -c '.vocabulary // [] | .[]' "${tracked}" | while read -r entry; do
      term="$(jq -r '.term' <<<"${entry}")"
      sounds_like="$(jq -r '.sounds_like // [] | join(",")' <<<"${entry}")"
      if [[ -n ${sounds_like} ]]; then
        "${hex}" vocabulary add "${term}" --sounds-like "${sounds_like}" >/dev/null
      else
        "${hex}" vocabulary add "${term}" >/dev/null
      fi
    done
  fi

  "${hex}" launch-at-login on >/dev/null
  save_snapshot
  echo "Applied Hex settings from ${tracked}"
}

dump() {
  if ! "${hex}" status >/dev/null 2>&1; then
    echo "Hex isn't running; start it with 'hex start' and try again" >&2
    exit 1
  fi
  if [[ ! -f ${snapshot} ]]; then
    echo "No snapshot at ${snapshot}; run '$0 apply' first so dump has a baseline" >&2
    exit 1
  fi

  current="$(current_settings)"
  vocabulary="$("${hex}" vocabulary list --json | jq '.entries')"
  changed="$(jq -n --argjson now "${current}" --slurpfile was "${snapshot}" --argjson excluded "${excluded}" '
    $now | with_entries(select(.value != $was[0][.key] and ([.key] | inside($excluded) | not)))')"

  [[ -f ${tracked} ]] || echo '{}' >"${tracked}"
  vocabulary_changed="$(jq --argjson vocabulary "${vocabulary}" '(.vocabulary // []) != $vocabulary' "${tracked}")"
  jq --indent 2 --argjson changed "${changed}" --argjson vocabulary "${vocabulary}" '
    {settings: ((.settings // {}) + $changed | to_entries | sort_by(.key) | from_entries),
     vocabulary: $vocabulary}' "${tracked}" >"${tracked}.tmp"
  mv "${tracked}.tmp" "${tracked}"
  printf '%s\n' "${current}" >"${snapshot}"

  if [[ ${changed} == "{}" && ${vocabulary_changed} == false ]]; then
    echo "No Hex settings changed since the last snapshot"
    return
  fi
  echo "Updated in ${tracked}:"
  jq -r 'keys[] | "  " + .' <<<"${changed}"
  if [[ ${vocabulary_changed} == true ]]; then
    echo "  vocabulary"
  fi
}

hex="$(hex_bin)"
if [[ -z ${hex} ]]; then
  echo "Skipping Hex settings: Hex isn't installed"
  exit 0
fi

case "${1:-}" in
apply) apply ;;
dump) dump ;;
*)
  echo "Usage: $0 apply|dump" >&2
  exit 2
  ;;
esac
