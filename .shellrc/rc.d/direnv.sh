#!/usr/bin/env sh

command -v direnv >/dev/null && eval "$(direnv hook $(basename ${SHELL}))"

