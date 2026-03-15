#!/bin/bash
# opencode-notifier custom command script
# Called by opencode-notifier when minDuration threshold is met.
# Args: --event <event> --message <message> --title <title>

EVENT=""
MESSAGE=""
TITLE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event)  EVENT="$2";   shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --title) TITLE_OVERRIDE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Map event types to sounds and subtitles
case "$EVENT" in
  complete)
    SOUND="Glass"
    SUBTITLE="Session Complete"
    ;;
  subagent_complete)
    SOUND="Pop"
    SUBTITLE="Subagent Complete"
    ;;
  error)
    SOUND="Basso"
    SUBTITLE="Error"
    ;;
  permission)
    SOUND="Ping"
    SUBTITLE="Permission Required"
    ;;
  question)
    SOUND="Purr"
    SUBTITLE="Question"
    ;;
  *)
    SOUND="default"
    SUBTITLE=""
    ;;
esac

TITLE="${TITLE_OVERRIDE:-OpenCode}"
GROUP_ID="opencode-${TMUX_PANE:-$PPID}"
SOUND_FILE="/System/Library/Sounds/${SOUND}.aiff"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON="$SCRIPT_DIR/icon.png"
GRACE_PERIOD=2

sleep "$GRACE_PERIOD"

if [[ -n "$TMUX_PANE" ]]; then
  STILL_WAITING=$(tmux show-option -wqv -t "$TMUX_PANE" @opencode-waiting 2>/dev/null)
  [[ "$STILL_WAITING" != "1" ]] && exit 0
fi

if command -v alerter >/dev/null 2>&1; then
  ALERTER_ARGS=(
    --title "$TITLE"
    --message "$MESSAGE"
    --group "$GROUP_ID"
    --timeout 15
  )
  [[ -n "$SUBTITLE" ]] && ALERTER_ARGS+=(--subtitle "$SUBTITLE")
  [[ -f "$ICON" ]] && ALERTER_ARGS+=(--app-icon "$ICON")
  alerter "${ALERTER_ARGS[@]}" >/dev/null 2>&1 &
  disown
elif command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -title "${SUBTITLE:+$SUBTITLE - }$TITLE" \
    -message "$MESSAGE" \
    -group "$GROUP_ID" \
    -activate "com.googlecode.iterm2" &
else
  osascript -e "display notification \"$MESSAGE\" with title \"${SUBTITLE:+$SUBTITLE - }$TITLE\"" &
fi

if [[ -f "$SOUND_FILE" ]]; then
  afplay "$SOUND_FILE"
fi

wait
