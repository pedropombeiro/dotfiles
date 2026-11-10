#!/usr/bin/env zsh

step_config_checks() {
  "${YADM_SCRIPTS}/checks.d/025-configs.zsh"
}

_update_register "config checks" step_config_checks
