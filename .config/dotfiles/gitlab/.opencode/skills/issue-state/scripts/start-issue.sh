#!/usr/bin/env bash
# "Start implementing" an issue:
#   1. Assign the issue to the current user.
#   2. Set the currently-active milestone (the one whose date range contains today).
#   3. Set the native Status to "In dev".
#
# Usage:
#   start-issue.sh <issue-url>
#   start-issue.sh <iid> -R <owner/repo>
#   start-issue.sh <issue-url> --status "In progress"   # override the start status name
#   start-issue.sh <issue-url> --no-milestone           # skip milestone assignment
#
# Milestone selection uses the project's active milestones (including ancestor/group
# milestones) and picks the one whose start_date..due_date window contains today.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

start_status="In dev"
set_milestone=1
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)
      start_status="$2"
      shift 2
      ;;
    --no-milestone)
      set_milestone=0
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

user_id="$(glab api user | jq -r '.id')"
[[ -n "$user_id" && "$user_id" != "null" ]] || die "could not resolve current user id"

put_args=(--method PUT "projects/${enc}/issues/${ISSUE_IID}" -f "assignee_ids[]=${user_id}")

milestone_title=""
if [[ "$set_milestone" -eq 1 ]]; then
  today="$(date +%F)"
  milestone_json="$(glab api "projects/${enc}/milestones?state=active&include_ancestors=true&per_page=100" |
    jq -c --arg today "$today" '
      [ .[]
        | select(.start_date != null and .due_date != null)
        | select(.start_date <= $today and .due_date >= $today) ]
      | sort_by(.due_date) | .[0] // empty')"
  if [[ -n "$milestone_json" ]]; then
    milestone_id="$(jq -r '.id' <<<"$milestone_json")"
    milestone_title="$(jq -r '.title' <<<"$milestone_json")"
    put_args+=(-f "milestone_id=${milestone_id}")
  else
    echo "warning: no active milestone covers ${today}; skipping milestone" >&2
  fi
fi

glab api "${put_args[@]}" >/dev/null

echo "${PROJECT_PATH}#${ISSUE_IID} assigned to current user${milestone_title:+, milestone: ${milestone_title}}"

"${SCRIPT_DIR}/set-issue-status.sh" "${args[0]}" "$start_status" "${args[@]:1}"
