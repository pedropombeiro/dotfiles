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
#   - Status already terminal (done/canceled)        -> leave as-is unless --force. Merging an MR
#                                                       without a closing pattern leaves the issue
#                                                       open at "Complete"; without this guard a
#                                                       later run would drag it back to "In review".
#   - Any related MR still an open draft/WIP         -> "In dev".
#   - Otherwise, at least one MR still open (review) -> "In review".
#   - All related MRs merged/closed (none open)      -> "In review" (merge/close handles "Complete").
#   - No related MRs at all                          -> leave as-is.
#
# Note: only the *draft* flag distinguishes "In dev" from "In review". Pushing more commits to an
# MR that is already in review does NOT move the issue back to "In dev" - convert the MR back to a
# Draft if that is what you want.
#
# Status is set by NAME via set-issue-status.sh; the label (workflow::*) is never touched.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

dry_run=0
force=0
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    dry_run=1
    shift
    ;;
  --force)
    force=1
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

# An open issue can still sit in a terminal status - e.g. an MR was merged
# without a closing pattern, so the close automation set "Complete" but never
# closed the issue. Re-deriving from MR state would regress that, so bail out.
if [[ "$force" -eq 0 ]]; then
  current="$(current_status_json)"
  if [[ -n "$current" ]] &&
    jq -e --argjson terminal "$TERMINAL_STATUS_CATEGORIES" \
      '.category as $c | $terminal | index($c) != null' <<<"$current" >/dev/null; then
    echo "${PROJECT_PATH}#${ISSUE_IID} is $(jq -r '.name' <<<"$current") ($(jq -r '.category' <<<"$current")); leaving status unchanged (use --force to override)"
    exit 0
  fi
fi

# Gather related + closing MRs (deduped by project + iid: IIDs are only unique
# within a project, and related MRs can come from other projects).
mrs_json="$({
  glab api "projects/${enc}/issues/${ISSUE_IID}/related_merge_requests" 2>/dev/null || echo '[]'
  glab api "projects/${enc}/issues/${ISSUE_IID}/closed_by" 2>/dev/null || echo '[]'
} | jq -s 'add | unique_by([.project_id, .iid])')"

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

summary="$(jq -r '[.[] | "!\(.iid)=\(.state)\(if (.draft or .work_in_progress) then " (draft)" else "" end)"] | join(", ")' <<<"$mrs_json")"
echo "MRs: ${summary}"
echo "target status: ${target}"

# All MRs merged but the issue is still open: whoever merged didn't use a closing
# pattern, so nothing will close this automatically. Deciding an issue is "done"
# needs human judgement (follow-up work may remain), so only report it.
all_merged="$(jq '[.[] | select(.state == "merged")] | length' <<<"$mrs_json")"
if [[ "$all_merged" -eq "$mr_count" ]]; then
  echo "note: all ${mr_count} MR(s) merged but the issue is still open - no closing pattern took effect."
  echo "      ask the user whether to close it (and set a done status); this script will not decide."
fi

if [[ "$dry_run" -eq 1 ]]; then
  echo "(dry-run) no changes made"
  exit 0
fi

"${SCRIPT_DIR}/set-issue-status.sh" "${args[0]}" "$target" "${args[@]:1}"
