#!/usr/bin/env bash

set -euo pipefail

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/colors.sh
source "${YADM_SCRIPTS}/colors.sh"

token_file="${HOME}/.config/lazy-mcp/memos-token"
token_dir="$(dirname "${token_file}")"

if [[ -s "${token_file}" ]]; then
  chmod 600 "${token_file}"
  printf "${GREEN}%s${NC}\n" "Memos MCP token file already exists"
  exit 0
fi

mkdir -p "${token_dir}"
umask 077
tmp_file=$(mktemp "${token_dir}/memos-token.XXXXXX")
trap 'rm -f "${tmp_file}"' EXIT

if command -v op >/dev/null 2>&1; then
  if op read "op://Private/Memos OpenCode API token/password" >"${tmp_file}" && \
    [[ -s "${tmp_file}" ]]; then
    mv "${tmp_file}" "${token_file}"
    chmod 600 "${token_file}"
    printf "${GREEN}%s${NC}\n" "Configured Memos MCP token from 1Password"
    exit 0
  fi

  printf "${YELLOW}%s${NC}\n" "Could not read the Memos MCP token from 1Password"
else
  printf "${YELLOW}%s${NC}\n" "1Password CLI is unavailable; cannot configure the Memos MCP token"
fi

# A placeholder keeps lazy-mcp available when 1Password is unavailable. Memos
# will return 401 until this file contains a personal access token.
: >"${token_file}"
chmod 600 "${token_file}"
printf "${YELLOW}%s${NC}\n" "Created an empty Memos MCP token file; add a personal access token to ${token_file}"
