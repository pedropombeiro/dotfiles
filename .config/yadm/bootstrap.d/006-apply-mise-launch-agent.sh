#!/usr/bin/env sh

[ "$(uname -s)" = "Darwin" ] || exit 0

legacy_agent="${HOME}/Library/LaunchAgents/com.pedro.latest-hidden.plist"
if [ -f "${legacy_agent}" ]; then
  launchctl bootout "gui/$(id -u)" "${legacy_agent}" 2>/dev/null || true
  rm -f "${legacy_agent}"
fi

mise bootstrap --only launchd --yes
