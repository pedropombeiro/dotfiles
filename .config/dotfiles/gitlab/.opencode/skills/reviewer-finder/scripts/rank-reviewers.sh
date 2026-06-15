#!/usr/bin/env bash
# Rank candidate reviewers per CODEOWNERS section using availability signals.
#
# Reads the JSON emitted by reviewer-signals.sh on stdin (or --in <file>).
#
# Scoring (lower score = better candidate):
#   - Hard-exclude:  ooo_now == true  -> dropped (kept under "excluded")
#   - load:          + load * LOAD_WEIGHT
#   - stale:         + STALE_PENALTY if stale (advisory; not excluded)
#   - sme bonus:     - SME_BONUS if the user is a recent author of the files
#   - timezone:      handoff-optimized by default (favor reviewers starting
#                    their day); with --coordination-heavy, favor overlap.
#                    Timezone is applied only when tz_offset is known.
#
# Options:
#   --author-tz <h>          Author UTC offset hours (e.g. 1, -5). Optional.
#   --coordination-heavy     Prefer timezone overlap with the author instead
#                            of handoff.
#   --in <file>              Read from file instead of stdin.
#
# Emits JSON on stdout:
#   {
#     project, iid, author,
#     sme: [ { section, required, ranked: [ {username, score, reasons,
#                covers_sections:[...], signals{...}} ], excluded: [...] } ],
#     maintainers: { ranked: [...], excluded: [...] },
#     overlap: { "<username>": ["Database","Backend"] }   # multi-section picks
#   }
#
# Requires: jq.
set -euo pipefail
die() {
  echo "rank-reviewers: $*" >&2
  exit 1
}
command -v jq >/dev/null || die "jq not found"

LOAD_WEIGHT=10
STALE_PENALTY=15
SME_BONUS=20
ROLE_MISMATCH_PENALTY=10
AUTHOR_TZ=""
COORDINATION_HEAVY=false
IN_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --author-tz)
    AUTHOR_TZ="$2"
    shift 2
    ;;
  --coordination-heavy)
    COORDINATION_HEAVY=true
    shift
    ;;
  --in)
    IN_FILE="$2"
    shift 2
    ;;
  *) die "unknown option: $1" ;;
  esac
done

if [[ -n "$IN_FILE" ]]; then IN="$(cat "$IN_FILE")"; else IN="$(cat)"; fi
[[ -n "$IN" ]] || die "no signals JSON on stdin"

[[ -n "$AUTHOR_TZ" ]] || AUTHOR_TZ=null

jq \
  --argjson load_w "$LOAD_WEIGHT" \
  --argjson stale_p "$STALE_PENALTY" \
  --argjson sme_b "$SME_BONUS" \
  --argjson role_p "$ROLE_MISMATCH_PENALTY" \
  --argjson author_tz "$AUTHOR_TZ" \
  --argjson coord "$COORDINATION_HEAVY" '
  def absn($x): if $x < 0 then -$x else $x end;

  # Map a CODEOWNERS section name to a coarse engineering domain, or null when
  # the section has no clear single domain (e.g. generic "Maintainers").
  def domain_of($section):
    ($section | ascii_downcase) as $s
    | if   ($s | test("frontend|vue|haml|graphql frontend")) then "frontend"
      elif ($s | test("database|migration|clickhouse"))      then "database"
      elif ($s | test("backend|rails|ruby|source code"))     then "backend"
      else null end;

  # Does a jobTitle clearly contradict the section domain? Only fires when the
  # title is present AND clearly indicates a different specialty (e.g. a
  # designer/PM/TW/UX in a code-review section). Advisory only.
  def role_mismatch($job; $section):
    ($job // "") as $j
    | ($j | ascii_downcase) as $jl
    | domain_of($section) as $dom
    | if ($jl == "" or $dom == null) then false
      else
        # Non-engineering roles that should not be the SME for code domains.
        ($jl | test("design|ux|ui designer|product manager|product designer|technical writer|tech writer|documentation|content"))
        # A frontend specialist in a backend section (and vice versa) is a
        # softer mismatch; only flag the clearly-cross-discipline cases above.
      end;

  def score($u; $sig; $recent; $section):
    ($sig[$u] // {}) as $s
    | ($s.load // 0) as $load
    | (if ($recent | index($u)) then -$sme_b else 0 end) as $sme
    | (if ($s.stale // false) then $stale_p else 0 end) as $stale
    | (if role_mismatch($s.job_title; $section) then $role_p else 0 end) as $role
    | ($s.tz_offset) as $tz
    | (if ($tz != null and $author_tz != null) then
         absn($tz - $author_tz) as $delta
         | (if $coord
             then ($delta * 2)                 # overlap: closer is better
             else absn($delta - 8)             # handoff: ~8h apart is ideal
            end)
       else 0 end) as $tzscore
    | ($load * $load_w) + $sme + $stale + $role + $tzscore;

  def reasons($u; $sig; $recent; $section):
    ($sig[$u] // {}) as $s
    | [ "load \($s.load // 0)",
        (if ($recent | index($u)) then "recent author (SME)" else empty end),
        (if ($s.no_footprint // false) then "no recent MR activity (advisory)"
         elif ($s.stale // false) then "idle \($s.days_idle)d (advisory)"
         else empty end),
        (if role_mismatch($s.job_title; $section)
         then "role mismatch: \($s.job_title) (advisory)" else empty end),
        (if ($s.job_title // "") != "" then "role: \($s.job_title)" else empty end),
        (if ($s.location // "") != "" then "loc \($s.location)" else empty end),
        (if ($s.status_message // "") != "" then "status: \($s.status_message)" else empty end)
      ];

  # Only rank candidates that actually have a gathered signal entry. Signal
  # gathering is capped (reviewer-signals.sh --max-candidates), so this keeps
  # the ranking limited to users we genuinely evaluated rather than padding it
  # with unevaluated names that would all score 0.
  def evaluated($sig; $list): [ $list[] | select($sig[.] != null) ];

  . as $root
  | .signals as $sig
  # Build per-section ranked SME lists.
  | (.sections | map(
      . as $sec
      | evaluated($sig; ($sec.members + $sec.recent_authors | unique)) as $cands
      | ($sec.recent_authors) as $recent
      | {
          section: $sec.name,
          required: $sec.required,
          ranked: (
            $cands
            | map(select(($sig[.] // {}).ooo_now != true))
            | map({ username: ., score: score(.; $sig; $recent; $sec.name),
                    reasons: reasons(.; $sig; $recent; $sec.name),
                    signals: ($sig[.] // {}) })
            | sort_by(.score)
          ),
          excluded: (
            $cands
            | map(select(($sig[.] // {}).ooo_now == true))
            | map({ username: ., reason: "OOO/PTO now",
                    status: (($sig[.] // {}).status_message // "") })
          )
        }
    )) as $sme
  # Maintainer pool (second-stage).
  | evaluated($sig; .maintainers.members // []) as $mcands
  | {
      project: .project,
      iid: .iid,
      author: .author,
      sme: $sme,
      maintainers: {
        ranked: (
          $mcands
          | map(select(($sig[.] // {}).ooo_now != true))
          | map({ username: ., score: score(.; $sig; []; "Maintainers"),
                  reasons: reasons(.; $sig; []; "Maintainers"),
                  signals: ($sig[.] // {}) })
          | sort_by(.score)
        ),
        excluded: (
          $mcands
          | map(select(($sig[.] // {}).ooo_now == true))
          | map({ username: ., reason: "OOO/PTO now" })
        )
      },
      # Candidates that satisfy more than one required SME section.
      overlap: (
        reduce $sme[] as $s ({};
          reduce ($s.ranked[].username) as $u (.;
            .[$u] += [$s.section]))
        | with_entries(select(.value | length > 1))
      )
    }
' <<<"$IN"
