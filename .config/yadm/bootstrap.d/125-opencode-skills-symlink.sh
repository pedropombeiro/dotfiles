#!/usr/bin/env bash

set -euo pipefail

mkdir -p "${HOME}/.config/opencode"
ln -sf "${HOME}/.agents/skills" "${HOME}/.config/opencode/skills"
