#!/usr/bin/env bash
# Set a work item's native Status by name (never touches labels).
#
# Usage:
#   set-issue-status.sh <issue-url> "In dev"
#   set-issue-status.sh <iid> "In review" -R <owner/repo>
#
# The status name must exist in the project's status lifecycle
# (run resolve-statuses.sh to list valid names).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# First positional is the ref, second is the status name; -R may follow.
ref="${1:-}"
status_name="${2:-}"
[[ -n "$ref" && -n "$status_name" ]] || die "usage: set-issue-status.sh <issue-url|iid> <status-name> [-R owner/repo]"
shift 2

parse_issue_ref "$ref" "$@"

status_id="$("${SCRIPT_DIR}/resolve-statuses.sh" "$ref" "$@" --name "$status_name")"
gid="$(work_item_gid)"
[[ -n "$gid" ]] || die "could not resolve work item ${PROJECT_PATH}#${ISSUE_IID}"

result="$(glab api graphql -f query="
mutation {
  workItemUpdate(input: {
    id: \"${gid}\",
    statusWidget: { status: \"${status_id}\" }
  }) {
    errors
    workItem {
      widgets { ... on WorkItemWidgetStatus { status { name } } }
    }
  }
}")"

errors="$(jq -r '.data.workItemUpdate.errors | join("; ")' <<<"$result")"
[[ -z "$errors" ]] || die "workItemUpdate failed: $errors"

new_status="$(jq -r '.data.workItemUpdate.workItem.widgets[] | select(.status) | .status.name' <<<"$result")"
echo "${PROJECT_PATH}#${ISSUE_IID} status -> ${new_status}"
