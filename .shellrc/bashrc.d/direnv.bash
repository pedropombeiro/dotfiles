#!/usr/bin/env bash

command -v direnv >/dev/null && eval "$(direnv hook $(basename ${SHELL}))"
