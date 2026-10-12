#!/usr/bin/env zsh

# Checks that the OpenCode background service can export telemetry, through
# the otel-status plugin's probe, which runs inside the service. A probe from
# this shell isn't enough: on macOS, Local Network Privacy can block the
# service's launch context while every terminal still reaches the collector.
# A service that started before tmux was re-signed, or under a tmux server
# that predates the signature, keeps failing until it restarts. See
# ~/.agents/docs/opencode.md#telemetry.
#
# When the service can't reach the collector, this script sends the same empty
# OTLP export from this shell (Apple's curl on macOS) to tell a launch-context
# problem apart from a collector, network, or credential problem.
#
# Usage: check-opencode-telemetry.zsh [--fix]
#   --fix  Restart the service once when only its launch context fails, unless
#          a session is running, then check again.

setopt EXTENDED_GLOB

YADM_SCRIPTS=$(cd -- "$(dirname -- "${(%):-%x}")/../scripts" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

function print_op_stay() {
  printf "${CYAN}%-63s${NC} " "- $1..."
}

function print_ok() {
  printf "${GREEN}%s${NC} %s\n" '✅ OK' "$1"
}

function print_failure() {
  printf "${RED}%s${NC}\n" "$1"
}

function print_warn() {
  printf "${YELLOW}%s${NC} %s\n" '⚠️  WARN' "$1"
}

fix=0
[[ $1 == --fix ]] && fix=1

# Asks the service to probe the collector now. Prints the status JSON.
function service_check() {
  opencode api post /api/rpc/otel-status/check --data '{"input":{}}' 2>/dev/null | jq -ce '.output | objects'
}

# Sends the empty OTLP metrics export from this shell, with the exporter's
# headers. Prints the HTTP status code, or 000 when the connection fails.
function shell_probe() {
  local endpoint=$1 protocol=$2 content_type body pair name
  case $protocol in
    http/protobuf) content_type=application/x-protobuf body= ;;
    http/json) content_type=application/json body='{}' ;;
    *) return 1 ;;
  esac
  local curl=curl
  [[ $(uname -s) == Darwin ]] && curl=/usr/bin/curl

  # Headers go through stdin to keep credentials out of the process list.
  # Split at the first `=`, as the exporter does.
  local -a header_lines
  for pair in ${(s:,:)OPENCODE_OTLP_HEADERS}; do
    [[ $pair == *=* ]] || continue
    name=${${pair%%=*}// /}
    [[ -n $name && ${(L)name} != content-type ]] || continue
    header_lines+=("${name}: ${${pair#*=}##[[:space:]]#}")
  done
  print -rl -- "${header_lines[@]}" |
    "$curl" -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 \
      -X POST -H @- -H "Content-Type: ${content_type}" --data-binary "$body" \
      "${endpoint%/}/v1/metrics" 2>/dev/null
  # curl prints 000 and exits non-zero when it can't connect.
  return 0
}

function active_sessions() {
  opencode api get /api/session/active 2>/dev/null | jq -er '.data | length'
}

# Restarts the service with the variables that its exporter reads from its
# environment: the credential from mise and host.name from the shell config.
function restart_service() {
  if [[ $OPENCODE_RESOURCE_ATTRIBUTES != *host.name=* ]]; then
    source "${HOME}/.shellrc/rc.d/opencode.sh"
  fi
  (cd "$HOME" && mise exec -- opencode service restart) >/dev/null 2>&1 || return 1
  # The plugin loads after the service starts listening.
  local attempt
  for attempt in {1..15}; do
    service_check >/dev/null && return 0
    sleep 2
  done
  return 1
}

function print_context_advice() {
  [[ $(uname -s) == Darwin ]] || return 0
  print_warn "macOS Local Network Privacy may block the service's launch context."
  print_warn "Check tmux with mise run dotfiles:checkhealth, then restart the service from a new terminal:"
  print_warn "  mise exec -- opencode service restart"
}

function check_opencode_telemetry() {
  print_op_stay "Checking OpenCode service telemetry export"

  if ! (( $+commands[opencode] && $+commands[jq] )); then
    print_ok "(skipped, needs opencode and jq)"
    return 0
  fi
  if ! opencode service status &>/dev/null; then
    print_ok "(skipped, service not running)"
    return 0
  fi

  local status_json state endpoint protocol error
  if ! status_json=$(service_check); then
    echo
    print_failure "The otel-status plugin didn't respond. Check that opencode.json loads it."
    return 1
  fi
  state=$(jq -r .state <<<"$status_json")
  # Confirm a failure, so that one slow response doesn't trigger a restart.
  if [[ $state == unreachable ]]; then
    sleep 3
    local retry
    retry=$(service_check) && status_json=$retry
    state=$(jq -r .state <<<"$status_json")
  fi
  endpoint=$(jq -r '.endpoint // empty' <<<"$status_json")
  protocol=$(jq -r .protocol <<<"$status_json")
  error=$(jq -r '.error // "unknown error"' <<<"$status_json")

  case $state in
    disabled)
      print_ok "(skipped, no endpoint configured)"
      return 0
      ;;
    reachable)
      if jq -e '.hostName' <<<"$status_json" >/dev/null; then
        print_ok "(${endpoint})"
      else
        print_ok
        print_warn "The service exports telemetry without host.name; restart it from a new shell"
      fi
      return 0
      ;;
  esac

  echo
  print_failure "The service can't export to ${endpoint}: ${error}"

  local code
  if ! code=$(shell_probe "$endpoint" "$protocol"); then
    print_warn "Can't compare from this shell over ${protocol}"
    print_context_advice
    return 1
  fi
  case $code in
    2??) ;;
    000)
      print_warn "This shell can't reach the collector either; check the collector and the network"
      return 1
      ;;
    401|403)
      print_warn "The collector rejected this shell's credential too (HTTP ${code}); see ~/.agents/docs/opencode.md#configure-telemetry-authentication"
      return 1
      ;;
    *)
      print_warn "The collector answered this shell with HTTP ${code}"
      return 1
      ;;
  esac

  print_warn "The collector accepts the same request from this shell, so the service's environment or launch context is at fault"
  if (( ! fix )); then
    print_context_advice
    return 1
  fi

  local sessions
  sessions=$(active_sessions)
  if [[ $sessions != <-> ]]; then
    print_warn "Can't list running sessions; not restarting the service"
    print_context_advice
    return 1
  fi
  if (( sessions > 0 )); then
    print_warn "${sessions} session(s) running; not restarting the service. Restart it when they finish:"
    print_warn "  mise exec -- opencode service restart"
    return 1
  fi

  printf "${YELLOW}%s${NC}\n" "Restarting the OpenCode service..."
  if ! restart_service; then
    print_failure "The service didn't come back with the otel-status plugin"
    return 1
  fi
  status_json=$(service_check)
  if [[ $(jq -r .state <<<"$status_json") == reachable ]]; then
    print_ok "(fixed by restarting the service)"
    return 0
  fi
  print_failure "Still failing after the restart: $(jq -r '.error // "unknown error"' <<<"$status_json")"
  print_context_advice
  return 1
}

check_opencode_telemetry
