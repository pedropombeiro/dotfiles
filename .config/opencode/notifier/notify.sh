#!/bin/bash
# opencode-notifier custom command script
# Called by opencode-notifier when minDuration threshold is met.
# Delegates to Hammerspoon's HTTP server for native macOS notifications
# with click-to-focus support for the originating tmux pane.
#
# Args: --event <event> --message <message> --title <title> --session <session ID>

HAMMERSPOON_PORT=18990
GRACE_PERIOD=2

EVENT=""
MESSAGE=""
TITLE_OVERRIDE=""
SESSION_ID=""

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
  --session)
    SESSION_ID="$2"
    shift 2
    ;;
  *) shift ;;
  esac
done

TITLE="${TITLE_OVERRIDE:-OpenCode}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON="$SCRIPT_DIR/icon.png"

# Echoes "PANE SOCKET" for the first pane whose opencode-tmux-indicator socket lists the
# session as waiting. Every TUI in a directory can host the session as a tab, so the
# notification click selects the tab through the socket before focusing the pane.
waiting_pane_for_session() {
  local session_id=$1 pane_id option socket
  while IFS= read -r pane_id; do
    while read -r option _; do
      [[ $option == @opencode-waiting-target-* ]] || continue
      socket=$(tmux show-option -pqv -t "$pane_id" "$option" 2>/dev/null)
      [[ -S $socket ]] || continue
      if curl --silent --fail --max-time 1 --unix-socket "$socket" http://localhost/waiting 2>/dev/null |
        grep -qF "\"$session_id\""; then
        printf '%s %s\n' "$pane_id" "$socket"
        return 0
      fi
    done < <(tmux show-options -p -t "$pane_id" 2>/dev/null)
  done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)
  return 1
}

# Wait briefly — the user may have already returned to the terminal,
# in which case the notification is unnecessary.
sleep "$GRACE_PERIOD"

PANE="${TMUX_PANE:-}"
SOCKET=""
if [[ -n "$SESSION_ID" ]] && tmux list-sessions &>/dev/null; then
  # The OpenCode 2 server runs this script, so $TMUX_PANE is the pane that started the
  # server, not the pane showing this session. Notify only while the session is still
  # waiting, and target a pane that hosts it.
  TARGET=$(waiting_pane_for_session "$SESSION_ID") || exit 0
  read -r PANE SOCKET <<<"$TARGET"
elif [[ -n "$TMUX_PANE" ]]; then
  # No session ID: fall back to the pane-wide flag set by the opencode tmux integration.
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

curl -sf "http://localhost:${HAMMERSPOON_PORT}/?action=notify&event=${EVENT}&message=$(urlencode "$MESSAGE")&title=$(urlencode "$TITLE")&pane=$(urlencode "$PANE")&socket=$(urlencode "$SOCKET")&session=$(urlencode "$SESSION_ID")&icon=$(urlencode "$ICON")"
