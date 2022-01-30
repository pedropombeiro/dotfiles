#!/usr/bin/env bash

alias busylight_red="curl -s 'http://localhost:8989?action=light&red=100'"
alias busylight_green="curl -s 'http://localhost:8989?action=light&green=100'"
alias busylight_off="curl -s 'http://localhost:8989?action=off'"

function busy() {
  curl -s 'http://localhost:8989?action=light&red=100' >/dev/null
  trap "curl -s 'http://localhost:8989?action=light&green=100' >/dev/null; trap - EXIT ERR HUP" EXIT ERR HUP

  "$@"
}
