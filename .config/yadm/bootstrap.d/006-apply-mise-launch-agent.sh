#!/usr/bin/env sh

[ "$(uname -s)" = "Darwin" ] || exit 0

mise bootstrap --only macos-launchd-agents --yes
