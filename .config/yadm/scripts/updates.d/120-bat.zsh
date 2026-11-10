#!/usr/bin/env zsh

step_bat() {
  bat cache --build
}

_update_register "bat theme" step_bat
