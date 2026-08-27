#!/usr/bin/env zsh

# QTS ships glibc 2.21 in /lib, while Entware ships 2.27 in /opt/lib. Tools
# built against a newer glibc install fine but fail at exec time, and the
# failure often only surfaces as noise in a new shell (see the atuin
# regression from mise 2026.8.9, https://github.com/jdx/mise/pull/12093).
#
# Compare each dynamically linked binary's highest required GLIBC_2.x symbol
# version against the glibc that its own ELF interpreter resolves to, so
# binaries using the Entware loader are judged against 2.27 rather than 2.21.

setopt LOCAL_OPTIONS EXTENDED_GLOB NULL_GLOB

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

# Tools with no musl or low-glibc build available upstream. These are already
# known to be unrunnable here, so they are reported quietly to keep a genuinely
# new regression visible instead of buried in expected noise. Drop an entry once
# upstream ships a compatible asset.
typeset -ga KNOWN_GLIBC_INCOMPATIBLE=(
  ipinfo  # only publishes one CGO-enabled linux/amd64 build
  jless   # only publishes unknown-linux-gnu, also needs libxcb
  rustnet # glibc asset selected, also needs libpcap
)

function print_op_stay() {
  printf "${CYAN}%-63s${NC} " "- $1..."
}

function print_ok() {
  printf "${GREEN}%s${NC} %s\n" '✅ OK' "$1"
}

function print_warn() {
  printf "${YELLOW}%s${NC} %s\n" '⚠️  WARN' "$1"
}

function print_note() {
  printf "${CYAN}%s${NC} %s\n" '   note' "$1"
}

# Highest glibc minor version offered by the libc next to a given ELF loader.
# Returns non-zero when the loader or its libc cannot be resolved, so callers
# can skip rather than guess.
function _glibc_minor_of_loader() {
  local loader="$1"
  local libc="${loader:h}/libc.so.6"
  [[ -e "$libc" ]] || return 1
  local real="${libc:A}"
  [[ "${real:t}" =~ 'libc-2\.([0-9]+)\.so' ]] || return 1
  print -r -- "${match[1]}"
}

function check_glibc_compat() {
  print_op_stay "Checking mise tools against available glibc"

  if ! (( $+commands[readelf] && $+commands[mise] )); then
    print_ok "(skipped, needs readelf and mise)"
    return 0
  fi

  local -A loader_minor
  local -a regressions known_hits
  local dir f interp need minor ceiling
  local scanned=0

  for dir in ${(f)"$(mise bin-paths 2>/dev/null)"}; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*(N-*); do
      [[ -f "$f" ]] || continue

      # Only dynamically linked ELF binaries can fail this way. Static Go
      # binaries, musl builds and shell scripts report no interpreter.
      interp=$(readelf -l "$f" 2>/dev/null |
        sed -n 's/.*Requesting program interpreter: \([^]]*\)\].*/\1/p')
      [[ -n "$interp" ]] || continue
      (( scanned++ ))

      need=$(readelf -V "$f" 2>/dev/null |
        grep -oE 'GLIBC_2\.[0-9]+' | sort -uV | tail -1)
      [[ -n "$need" ]] || continue
      minor="${need##GLIBC_2.}"

      if [[ -z "${loader_minor[$interp]}" ]]; then
        loader_minor[$interp]=$(_glibc_minor_of_loader "$interp" || print -r -- -1)
      fi
      ceiling="${loader_minor[$interp]}"

      # An unresolvable loader is a missing-dependency problem, not a version
      # mismatch, so leave it to the tool's own error message.
      (( ceiling < 0 )) && continue
      (( minor > ceiling )) || continue

      if (( ${KNOWN_GLIBC_INCOMPATIBLE[(Ie)${f:t}]} )); then
        known_hits+=("${f:t} (needs 2.${minor})")
      else
        regressions+=("${f:t} needs GLIBC 2.${minor}, ${interp:h} provides 2.${ceiling}")
      fi
    done
  done

  if (( ${#regressions} == 0 )); then
    print_ok "(${scanned} dynamic binaries)"
    (( ${#known_hits} )) &&
      print_note "known incompatible, no upstream musl build: ${(j:, :)known_hits}"
    return 0
  fi

  echo
  local entry
  for entry in "${regressions[@]}"; do
    print_warn "$entry"
  done
  print_warn "Check 'mise settings get libc' and whether upstream ships a musl asset"
  (( ${#known_hits} )) &&
    print_note "known incompatible, ignored: ${(j:, :)known_hits}"
  return 1
}

check_glibc_compat
