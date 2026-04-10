#!/bin/bash
# opencode-notifier custom command script
# Called by opencode-notifier when minDuration threshold is met.
# Delegates to Hammerspoon's HTTP server for native macOS notifications
# with click-to-focus support for the originating tmux pane.
#
# Args: --event <event> --message <message> --title <title>

HAMMERSPOON_PORT=18990
GRACE_PERIOD=2

EVENT=""
MESSAGE=""
TITLE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --event)
    EVENT="$2"
    shift 2
    ;;
  --message)
    MESSAGE="$2"
    shift 2
    ;;
  --title)
    TITLE_OVERRIDE="$2"
    shift 2
    ;;
  *) shift ;;
  esac
done

TITLE="${TITLE_OVERRIDE:-OpenCode}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON="$SCRIPT_DIR/icon.png"

# Wait briefly — the user may have already returned to the terminal,
# in which case the notification is unnecessary.
sleep "$GRACE_PERIOD"

# If running inside tmux, check whether the pane is still waiting.
# The @opencode-waiting flag is set/cleared by the opencode tmux integration.
if [[ -n "$TMUX_PANE" ]]; then
  STILL_WAITING=$(tmux show-option -wqv -t "$TMUX_PANE" @opencode-waiting 2>/dev/null)
  [[ "$STILL_WAITING" != "1" ]] && exit 0
fi

# Percent-encode a string for use in query parameters (pure bash)
urlencode() {
  local LC_ALL=C char
  while IFS= read -r -n1 char; do
    case "$char" in
    [a-zA-Z0-9.~_-]) printf '%s' "$char" ;;
    '') printf '%%20' ;;
    *) printf '%%%02X' "'$char" ;;
    esac
  done < <(printf '%s' "$1")
}

curl -sf "http://localhost:${HAMMERSPOON_PORT}/?action=notify&event=${EVENT}&message=$(urlencode "$MESSAGE")&title=$(urlencode "$TITLE")&pane=$(urlencode "${TMUX_PANE:-}")&icon=$(urlencode "$ICON")"
