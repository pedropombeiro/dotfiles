#!/usr/bin/env zsh

step_tldr() {
  tldr --update
}

_update_register "tldr" step_tldr
