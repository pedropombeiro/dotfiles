#!/usr/bin/env bash
# Sync an issue's native Status to match the progress of its merge requests.
#
# Usage:
#   sync-issue-state.sh <issue-url>
#   sync-issue-state.sh <iid> -R <owner/repo>
#   sync-issue-state.sh <issue-url> --dry-run    # print the decision, do not change anything
#
# Rules (see SKILL.md):
#   - Issue already closed                          -> leave as-is (Status usually auto-set to a
#                                                       done category on close).
#   - Any related MR still an open draft/WIP         -> "In dev".
#   - Otherwise, at least one MR still open (review) -> "In review".
#   - All related MRs merged/closed (none open)      -> "In review" (merge/close handles "Complete").
#   - No related MRs at all                          -> leave as-is.
#
# Status is set by NAME via set-issue-status.sh; the label (workflow::*) is never touched.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

dry_run=0
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

parse_issue_ref "${args[@]}"
enc="$(enc_path "$PROJECT_PATH")"

issue_state="$(glab api "projects/${enc}/issues/${ISSUE_IID}" | jq -r '.state')"
if [[ "$issue_state" == "closed" ]]; then
  echo "${PROJECT_PATH}#${ISSUE_IID} is closed; leaving status unchanged"
  exit 0
fi

# Gather related + closing MRs (deduped by iid).
mrs_json="$( {
  glab api "projects/${enc}/issues/${ISSUE_IID}/related_merge_requests" 2>/dev/null || echo '[]'
  glab api "projects/${enc}/issues/${ISSUE_IID}/closed_by" 2>/dev/null || echo '[]'
} | jq -s 'add | unique_by(.iid)')"

mr_count="$(jq 'length' <<<"$mrs_json")"
if [[ "$mr_count" -eq 0 ]]; then
  echo "${PROJECT_PATH}#${ISSUE_IID} has no related MRs; leaving status unchanged"
  exit 0
fi

# Determine target status name.
# An open MR that is still a draft counts as "in dev"; otherwise it is "in review".
open_draft="$(jq '[.[] | select(.state == "opened") | select(.draft == true or .work_in_progress == true)] | length' <<<"$mrs_json")"

if [[ "$open_draft" -gt 0 ]]; then
  target="In dev"
else
  target="In review"
fi

summary="$(jq -r '[.[] | "!\(.iid)=\(.state)\(if .draft then " (draft)" else "" end)"] | join(", ")' <<<"$mrs_json")"
echo "MRs: ${summary}"
echo "target status: ${target}"

if [[ "$dry_run" -eq 1 ]]; then
  echo "(dry-run) no changes made"
  exit 0
fi

"${SCRIPT_DIR}/set-issue-status.sh" "${args[0]}" "$target" "${args[@]:1}"
