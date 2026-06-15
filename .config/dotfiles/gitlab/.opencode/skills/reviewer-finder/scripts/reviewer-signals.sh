#!/usr/bin/env bash
# Gather per-candidate availability signals for reviewer ranking.
#
# Reads the JSON emitted by candidate-reviewers.sh on stdin (or --in <file>).
# For every distinct candidate username (across all sections + maintainers),
# computes via batched GraphQL:
#   - load:          outstanding review-requested MRs (review state != approved)
#   - availability:  user status (availability/message/emoji)
#   - ooo_now:       true if status indicates current OOO/PTO (hard-exclude)
#   - location:      profile location string (timezone hint)
#   - tz_offset:     UTC offset hours if derivable, else null (usually null)
#   - days_idle:     days since the most recent *contribution* (latest authored
#                    or reviewer-requested MR update). NOT lastActivityOn, which
#                    also ticks on bare sign-ins and over-reports liveness.
#   - stale:         days_idle >= STALE_DAYS (advisory only)
#   - last_activity_on: raw lastActivityOn date, kept as a weak secondary hint
#
# All signals come from a single GraphQL field set per user, fetched in chunks
# of --chunk-size users per request. This is dramatically faster than the old
# per-user REST approach (one ~0.7s GraphQL call per chunk vs. several
# multi-second REST calls per user), so we can afford to evaluate every
# candidate rather than sampling an arbitrary alphabetical window.
#
# Options:
#   --stale-days <n>     Advisory inactivity threshold (default: 3)
#   --chunk-size <n>     Usernames per GraphQL request (default: 40)
#   --max-candidates <n> Safety cap on total candidates evaluated (default: 400)
#   --in <file>          Read candidate JSON from a file instead of stdin
#
# Emits the input JSON augmented with a top-level "signals" map:
#   { ... , "signals": { "<username>": { load, ooo_now, stale, days_idle,
#                                        availability, status_message,
#                                        location, tz_offset } } }
#
# Requires: glab (authenticated), jq, date.
set -euo pipefail

die() {
  echo "reviewer-signals: $*" >&2
  exit 1
}
command -v glab >/dev/null || die "glab not found"
command -v jq >/dev/null || die "jq not found"

STALE_DAYS=3
CHUNK_SIZE=10
CONCURRENCY=12
MAX_CANDIDATES=400
IN_FILE=""
PTO_RE='PTO|OOO|out of office|on leave|vacation|holiday|annual leave|parental'

while [[ $# -gt 0 ]]; do
  case "$1" in
  --stale-days)
    STALE_DAYS="$2"
    shift 2
    ;;
  --chunk-size)
    CHUNK_SIZE="$2"
    shift 2
    ;;
  --concurrency)
    CONCURRENCY="$2"
    shift 2
    ;;
  --max-candidates)
    MAX_CANDIDATES="$2"
    shift 2
    ;;
  --in)
    IN_FILE="$2"
    shift 2
    ;;
  *) die "unknown option: $1" ;;
  esac
done

if [[ -n "$IN_FILE" ]]; then IN="$(cat "$IN_FILE")"; else IN="$(cat)"; fi
[[ -n "$IN" ]] || die "no candidate JSON on stdin"

# Distinct candidate usernames across all sections + maintainers. Order does
# not matter for correctness now (GraphQL evaluates everyone cheaply), but we
# keep recent authors first so the safety cap, if ever hit, favors SMEs.
mapfile -t USERS < <(
  jq -r '
    ( [ (.sections[].recent_authors[]?),
        (.sections[].members[]?),
        (.maintainers.members[]?) ] )
    | reduce .[] as $u ([]; if (. | index($u)) then . else . + [$u] end)
    | .[]' <<<"$IN" | head -n "$MAX_CANDIDATES"
)
[[ ${#USERS[@]} -gt 0 ]] || die "no candidate usernames found"

now_epoch="$(date -u +%s)"

# Build and run one GraphQL query for a chunk of usernames via the plural
# users(usernames: [...]) field, writing the resulting nodes array to a file.
#
# The per-user lastAuthored/lastReviewed subqueries (sorted MR lookups) are
# expensive, so chunks are kept small and a partial response (some nodes plus
# "Timeout on ..." errors) is tolerated: we keep whatever nodes came back and
# never propagate invalid JSON. Missing/partial users simply get no signal
# entry and are treated as "unknown" downstream.
#
# NOTE: top-level aliased `user(username:)` calls mis-resolve under GitLab's
# batchloader (aliases collide); the plural `users(usernames:)` field is the
# reliable way to fetch many users in one request.
fetch_chunk() {
  local names_json="$1"
  local out="$2"
  local query
  query="$(
    jq -rn --argjson names "$names_json" '
      "{ users(usernames: " + ($names | tojson) + ") { nodes { " +
      "username bot jobTitle location lastActivityOn " +
      "status { availability message emoji } " +
      "reviewRequestedMergeRequests(state: opened, reviewStates: [UNREVIEWED, REVIEWED, REQUESTED_CHANGES]) { count } " +
      "lastAuthored: authoredMergeRequests(first: 1, sort: UPDATED_DESC) { nodes { updatedAt } } " +
      "lastReviewed: reviewRequestedMergeRequests(first: 1, sort: UPDATED_DESC) { nodes { updatedAt } } " +
      "} } }"'
  )"
  # Keep only non-null node objects with a username; tolerate partial data.
  glab api graphql -f query="$query" 2>/dev/null |
    jq -c '[ (.data.users.nodes // [])[] | select(type == "object" and .username != null) ]' \
      2>/dev/null >"$out" || echo '[]' >"$out"
  [[ -s "$out" ]] || echo '[]' >"$out"
}

# Fetch all chunks concurrently with a bounded worker pool; each writes its
# nodes array to its own temp file. Total wall time ~= slowest chunk rather
# than the sum, which matters because each chunk is ~15s.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

active_jobs() { jobs -rp | wc -l | tr -d ' '; }

total=${#USERS[@]}
i=0
c=0
while [[ $i -lt $total ]]; do
  chunk=("${USERS[@]:i:CHUNK_SIZE}")
  names_json="$(printf '%s\n' "${chunk[@]}" | jq -R . | jq -s .)"
  while [[ "$(active_jobs)" -ge "$CONCURRENCY" ]]; do wait -n 2>/dev/null || break; done
  fetch_chunk "$names_json" "$WORK_DIR/chunk-$c.json" &
  i=$((i + CHUNK_SIZE))
  c=$((c + 1))
done
wait

RAW_NODES="$(cat "$WORK_DIR"/chunk-*.json 2>/dev/null | jq -cs 'add // []')"
[[ -n "$RAW_NODES" ]] || RAW_NODES="[]"

# Transform raw nodes into the signals map, applying OOO/stale derivation.
SIGNALS="$(
  jq -n \
    --argjson nodes "$RAW_NODES" \
    --argjson now "$now_epoch" \
    --argjson stale_days "$STALE_DAYS" \
    --arg pto_re "$PTO_RE" '
    # Parse an ISO timestamp (date or datetime) to epoch seconds, else null.
    def toepoch($d):
      if ($d == null or $d == "") then null
      elif ($d | test("T")) then ($d | fromdateiso8601)
      else (($d + "T00:00:00Z") | fromdateiso8601)
      end;
    def daysfrom($epoch):
      if $epoch == null then null else (($now - $epoch) / 86400 | floor) end;
    reduce $nodes[] as $n ({};
      # Skip bot users and service accounts (e.g. *-bot, *securitybot); they
      # are never valid human reviewers.
      if (($n.bot // false)
          or ($n.username | test("(^|[._-])bot([._-]|$)|securitybot"; "i")))
      then .
      else
      ($n.status // {}) as $st
      | ($st.availability // "") as $avail
      | ($st.message // "") as $msg
      | ($st.emoji // "") as $emoji
      # Contribution recency: the most recent of the latest authored-MR and
      # reviewer-requested-MR update. This reflects real engineering activity,
      # unlike lastActivityOn which also ticks on bare sign-ins/token use and
      # can falsely report "active today" for someone idle for weeks.
      | toepoch($n.lastAuthored.nodes[0].updatedAt) as $a
      | toepoch($n.lastReviewed.nodes[0].updatedAt) as $r
      | ( [ $a, $r ] | map(select(. != null)) | (if length == 0 then null else max end) ) as $contrib_epoch
      | daysfrom($contrib_epoch) as $idle
      | (($avail | ascii_downcase) == "busy"
         or ($msg != "" and ($msg | test($pto_re; "i")))
         or ($emoji != "" and (["palm_tree","beach","beach_with_umbrella","desert_island"] | any(. == $emoji)))
        ) as $ooo
      # No contribution footprint at all (no authored or reviewed MRs found):
      # not "neutral/unknown" — it means the candidate has no demonstrable
      # recent engineering activity, so we should not risk routing a review to
      # them. Flag as stale so the staleness penalty applies.
      | ($contrib_epoch == null) as $no_footprint
      | . + {
          ($n.username): {
            load: ($n.reviewRequestedMergeRequests.count // 0),
            ooo_now: $ooo,
            days_idle: $idle,
            no_footprint: $no_footprint,
            stale: (if $no_footprint then true else ($idle >= $stale_days) end),
            availability: $avail,
            status_message: $msg,
            status_emoji: $emoji,
            job_title: ($n.jobTitle // ""),
            location: ($n.location // ""),
            last_activity_on: ($n.lastActivityOn // null),
            tz_offset: null
          }
        }
      end
    )'
)"
[[ -n "$SIGNALS" ]] || SIGNALS="{}"

# Merge pre-gathered signals from candidate-reviewers.sh (group expansion).
# The pre-gathered `load` is the gitlab-dashboard active-review count
# (open, recent, not approved-by-the-reviewer) — preferred over the
# reviewStates count fetched here. job_title/location from expansion fill any
# gaps. Contribution-recency fields (days_idle/no_footprint) only exist here,
# so they always come from SIGNALS.
jq \
  --argjson sig "$SIGNALS" \
  '(.member_signals // {}) as $pre
   | .signals = (
       ($sig | keys) + ($pre | keys) | unique
       | map(select(test("(^|[._-])bot([._-]|$)|securitybot"; "i") | not))
       | reduce .[] as $u ({};
           ($sig[$u] // {}) as $s
           | ($pre[$u] // {}) as $p
           | .[$u] = ($s + {
               load: ($p.load // $s.load // 0),
               job_title: (if ($s.job_title // "") != "" then $s.job_title else ($p.job_title // "") end),
               location: (if ($s.location // "") != "" then $s.location else ($p.location // "") end),
               assigned_open: ($p.assigned_open // null)
             })
         )
     )
   | del(.member_signals)' <<<"$IN"
