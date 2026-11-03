#!/usr/bin/env bash
#
# Sync Hex (https://anoma.ly/hex) settings with ~/.config/yadm/hex-settings.json.
#
#   apply  Start Hex, apply the tracked settings, vocabulary, and speech model, and
#          save a snapshot.
#   dump   Add the settings changed since the snapshot, the current vocabulary, and
#          the speech model to the tracked file.
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
    # After the settings, so a model behind a Labs toggle is available. Downloads it
    # if it's missing, and does nothing if it's already in use.
    model="$(jq -r '.transcription.model // empty' "${tracked}")"
    if [[ -n ${model} ]]; then
      language="$(jq -r '.transcription.language // empty' "${tracked}")"
      "${hex}" model install "${model}" ${language:+--language "${language}"}
    fi
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
  changed="$(jq -n --argjson now "${current}" --slurpfile was "${snapshot}" --argjson excluded "${excluded}" '
    $now | with_entries(select(.value != $was[0][.key] and ([.key] | inside($excluded) | not)))')"
  # The vocabulary and speech model aren't writable settings, so they replace the
  # tracked copies as a whole.
  replaced="$(jq -n \
    --argjson vocabulary "$("${hex}" vocabulary list --json | jq '.entries')" \
    --argjson transcription "$("${hex}" settings get transcription --json |
      jq '[.settings[] | {(.key | ltrimstr("transcription.")): .value}] | add')" \
    '{vocabulary: $vocabulary, transcription: $transcription}')"

  [[ -f ${tracked} ]] || echo '{}' >"${tracked}"
  replaced_keys="$(jq -r --argjson replaced "${replaced}" '
    . as $old | $replaced | to_entries[] | select(.value != $old[.key]) | "  " + .key' "${tracked}")"
  jq --indent 2 --argjson changed "${changed}" --argjson replaced "${replaced}" '
    {settings: ((.settings // {}) + $changed | to_entries | sort_by(.key) | from_entries)} + $replaced' \
    "${tracked}" >"${tracked}.tmp"
  mv "${tracked}.tmp" "${tracked}"
  printf '%s\n' "${current}" >"${snapshot}"

  if [[ ${changed} == "{}" && -z ${replaced_keys} ]]; then
    echo "No Hex settings changed since the last snapshot"
    return
  fi
  echo "Updated in ${tracked}:"
  jq -r 'keys[] | "  " + .' <<<"${changed}"
  if [[ -n ${replaced_keys} ]]; then
    echo "${replaced_keys}"
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
