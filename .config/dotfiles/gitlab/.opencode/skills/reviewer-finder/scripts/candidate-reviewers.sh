#!/usr/bin/env bash
# Determine candidate reviewers for an MR from GitLab's own approval rules.
#
# Reads the JSON emitted by resolve-mr.sh on stdin (or via --mr-json <file>).
#
# Usage:
#   resolve-mr.sh <mr> | candidate-reviewers.sh
#   candidate-reviewers.sh --mr-json /tmp/mr.json
#
# Source of truth: the MR's GraphQL `approvalState.rules`. GitLab computes which
# CODE_OWNER rules apply to *this* MR and exposes the exact `eligibleApprovers`
# per rule — the same set shown in the MR Review widget (e.g. "153 code owners
# for /spec/"). This is authoritative: no CODEOWNERS glob parsing, no group
# membership expansion, and therefore none of the inherited-member problems
# (e.g. a UX designer wrongly appearing in a backend maintainer pool).
#
# Each CODE_OWNER rule becomes a "section". Its eligibleApprovers are the
# candidates, and per-approver signals (jobTitle, status, location,
# lastActivityOn, active reviews) are fetched inline in the same query and
# reused by reviewer-signals.sh.
#
# Stage classification:
#   - A rule whose `section` is the generic "Maintainers" fallback feeds the
#     second-stage maintainer pool.
#   - Every other CODE_OWNER rule is a first-stage SME requirement.
#
# Options:
#   --recent-authors <n>        Recent git authors to add as SME hints (default 5)
#   --active-reviews-days <n>    Deprecated no-op (load is computed by
#                                reviewer-signals.sh). Accepted for compatibility.
#   --include-satisfied          Also include rules already satisfied
#                                (approvalsRequired == 0). Default: only rules
#                                that still need approval.
#   --mr-json <file>             Read MR JSON from a file instead of stdin
#
# Emits JSON on stdout:
#   {
#     project, iid, author,
#     sections: [ { name, required, stage:"sme", optional:false,
#                   members:[usernames], recent_authors:[...] } ],
#     maintainers: { members:[usernames] },
#     member_signals: {}   # always empty; reviewer-signals.sh gathers signals
#   }
#
# Requires: glab (authenticated), jq, git.
set -euo pipefail

die() {
  echo "candidate-reviewers: $*" >&2
  exit 1
}

command -v glab >/dev/null || die "glab not found"
command -v jq >/dev/null || die "jq not found"

RECENT_AUTHORS=5
INCLUDE_SATISFIED=false
MR_JSON_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --recent-authors)
    RECENT_AUTHORS="$2"
    shift 2
    ;;
  --active-reviews-days)
    # Deprecated no-op kept for backward compatibility.
    shift 2
    ;;
  --include-satisfied)
    INCLUDE_SATISFIED=true
    shift
    ;;
  --mr-json)
    MR_JSON_FILE="$2"
    shift 2
    ;;
  *) die "unknown option: $1" ;;
  esac
done

if [[ -n "$MR_JSON_FILE" ]]; then
  MR_JSON="$(cat "$MR_JSON_FILE")"
else
  MR_JSON="$(cat)"
fi
[[ -n "$MR_JSON" ]] || die "no MR JSON on stdin"

PROJECT="$(jq -r '.project' <<<"$MR_JSON")"
IID="$(jq -r '.iid' <<<"$MR_JSON")"
[[ -n "$PROJECT" && "$PROJECT" != "null" ]] || die "MR JSON missing project"
[[ -n "$IID" && "$IID" != "null" ]] || die "MR JSON missing iid"

# --- Query the MR's approval rules (the SSOT for eligible approvers).
#
# IMPORTANT: this query is deliberately LIGHTWEIGHT — it fetches only the
# identity fields (`username bot state`) per eligible approver, NOT per-approver
# signals (active reviews, assigned MRs, jobTitle, location, status). Broad
# CODE_OWNER rules can have very large approver sets (e.g. the doc's cited "153
# code owners for /spec/"); inlining signal subqueries for every one of them
# made GitLab's GraphQL resolver partially time out and return a truncated/
# invalid payload, which then broke the downstream pipeline with
# "jq: invalid JSON text passed to --argjson".
#
# All per-candidate signals (load, status, location, idle, jobTitle) are
# gathered separately and efficiently by reviewer-signals.sh via batched,
# concurrent `users(usernames: [...])` requests. candidate-reviewers.sh
# therefore emits an empty member_signals map; the merge in reviewer-signals.sh
# tolerates that (it uses `// {}`), so the output contract is unchanged.
QUERY='query($fullPath: ID!, $iid: String!) {
  project(fullPath: $fullPath) {
    mergeRequest(iid: $iid) {
      approvalState {
        rules {
          name
          section
          type
          approvalsRequired
          approved
          eligibleApprovers { username bot state }
        }
      }
    }
  }
}'

RESP="$(glab api graphql \
  -f query="$QUERY" \
  -f fullPath="$PROJECT" \
  -f iid="$IID" 2>/dev/null || echo '{}')"

# If GraphQL returned errors (e.g. a resolver timeout on a very large rule's
# eligibleApprovers), the rules payload may be partial/invalid. Fail clearly
# rather than passing malformed JSON downstream.
if jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1 <<<"$RESP"; then
  err_msg="$(jq -r '[.errors[].message] | unique | join("; ")' <<<"$RESP" 2>/dev/null || echo "unknown GraphQL error")"
  die "GraphQL error fetching approval rules for ${PROJECT}!${IID}: ${err_msg}"
fi

RULES="$(jq -c '.data.project.mergeRequest.approvalState.rules // []' <<<"$RESP" 2>/dev/null || echo '[]')"
# Guard against malformed/partial JSON before it reaches the final jq -n.
jq -e . >/dev/null 2>&1 <<<"$RULES" || die "could not parse approval rules for ${PROJECT}!${IID} (partial response?)"
[[ "$RULES" != "[]" && -n "$RULES" ]] || die "no approval rules returned for ${PROJECT}!${IID} (is the MR accessible?)"

# Warn (don't fail) when there are no CODE_OWNER rules still needing approval —
# e.g. a merged or already-approved MR. Output will then have empty sections.
PENDING_CO="$(jq -r '[.[] | select(.type == "CODE_OWNER" and (.approvalsRequired // 0) > 0)] | length' <<<"$RULES" 2>/dev/null | head -1)"
[[ "$PENDING_CO" =~ ^[0-9]+$ ]] || PENDING_CO=0
if [[ "$PENDING_CO" -eq 0 && "$INCLUDE_SATISFIED" != "true" ]]; then
  echo "candidate-reviewers: note: ${PROJECT}!${IID} has no CODE_OWNER rules awaiting approval (merged/approved?). Use --include-satisfied to list all eligible approvers anyway." >&2
fi

# --- Recent git authors for the changed files (soft SME hint).
mapfile -t FILES < <(jq -r '.files[]?' <<<"$MR_JSON")
RECENT="$(
  if [[ ${#FILES[@]} -gt 0 ]]; then
    git log -n 50 --pretty='%ae' -- "${FILES[@]}" 2>/dev/null |
      sed -E 's/@.*//' | awk 'NF' |
      grep -viE '^(noreply|no-reply|gitlab|root|admin|.+\+.+)$' |
      grep -vE '^\.' |
      sort | uniq -c | sort -rn |
      head -n "$RECENT_AUTHORS" | awk '{print $2}'
  fi
)"
RECENT_JSON="$(printf '%s\n' "$RECENT" | awk 'NF' | jq -R . | jq -s .)"

# --- Transform rules → sections + maintainer pool + member_signals.
# A bot/service-account filter still applies (some report bot=false).
BOT_RE='(^|[._-])bot([._-]|$)|securitybot'

jq -n \
  --argjson mr "$MR_JSON" \
  --argjson rules "$RULES" \
  --argjson recent "$RECENT_JSON" \
  --argjson include_satisfied "$INCLUDE_SATISFIED" \
  --arg bot_re "$BOT_RE" '
  # An eligible approver is a real reviewer candidate when active, not a bot,
  # and not a service account by name.
  def usable($a):
    ($a != null)
    and (($a.bot // false) | not)
    and (($a.state // "active") == "active")
    and (($a.username // "" | test($bot_re; "i")) | not);

  # Is this rule the generic maintainer fallback (vs. an area SME rule)?
  def is_maint($r): ((($r.section // "") | ascii_downcase) == "maintainers");

  # Keep CODE_OWNER rules; by default only those still requiring approval.
  ( $rules
    | map(select(.type == "CODE_OWNER"))
    | map(select($include_satisfied or (.approvalsRequired // 0) > 0))
  ) as $corules

  # Build per-rule member username lists.
  | ( [ $corules[] | select(is_maint(.) | not)
      | { name: .name,
          required: ((.approvalsRequired // 0) > 0),
          stage: "sme",
          optional: false,
          members: [ .eligibleApprovers[] | select(usable(.)) | .username ],
          recent_authors: $recent }
    ] ) as $sme_sections

  | ( [ $corules[] | select(is_maint(.))
        | .eligibleApprovers[] | select(usable(.)) | .username ] | unique ) as $maint_members

  # Per-candidate signals (load, status, location, idle, jobTitle) are gathered
  # downstream by reviewer-signals.sh, which evaluates every username via
  # batched GraphQL. We intentionally emit an empty map here so this script
  # stays cheap and never trips the eligibleApprovers resolver timeout.
  | {
      project: $mr.project,
      iid: $mr.iid,
      author: $mr.author,
      sections: $sme_sections,
      maintainers: { members: $maint_members },
      member_signals: {}
    }
'
