#!/usr/bin/env bash

# OpenCode rewrites ~/.config/opencode/cli.json through a temp file and a rename
# whenever a setting changes in the UI, which would replace a yadm alternate
# symlink. The tracked terminal config lives in cli.base.json instead and reaches
# OpenCode through OPENCODE_CLI_CONFIG_CONTENT, which overrides cli.json and is
# never written back to it. cli.json stays an untracked file that OpenCode owns.
opencode_cli_base="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/cli.base.json"
if [[ -r "$opencode_cli_base" ]]; then
  OPENCODE_CLI_CONFIG_CONTENT="$(<"$opencode_cli_base")"
  export OPENCODE_CLI_CONFIG_CONTENT
fi
unset opencode_cli_base
