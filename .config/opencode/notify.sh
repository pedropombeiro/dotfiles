#!/bin/bash
# opencode-notifier custom command script
# Called by opencode-notifier when minDuration threshold is met.
# Args: --event <event> --message <message>

EVENT=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event)  EVENT="$2";   shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Map event types to sounds and titles
case "$EVENT" in
  complete)
    SOUND="Glass"
    TITLE="Session Complete"
    ;;
  subagent_complete)
    SOUND="Pop"
    TITLE="Subagent Complete"
    ;;
  error)
    SOUND="Basso"
    TITLE="Error"
    ;;
  permission)
    SOUND="Ping"
    TITLE="Permission Required"
    ;;
  question)
    SOUND="Purr"
    TITLE="Question"
    ;;
  *)
    SOUND="default"
    TITLE="OpenCode"
    ;;
esac

# Play sound separately via afplay to avoid clipping
SOUND_FILE="/System/Library/Sounds/${SOUND}.aiff"
if [[ -f "$SOUND_FILE" ]]; then
  afplay "$SOUND_FILE" &
fi

osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
