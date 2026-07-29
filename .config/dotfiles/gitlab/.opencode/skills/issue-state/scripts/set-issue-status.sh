#!/usr/bin/env bash
# Set a work item's native Status by name (never touches labels).
#
# Usage:
#   set-issue-status.sh <issue-url> "In dev"
#   set-issue-status.sh <iid> "In review" -R <owner/repo>
#
# The status name must exist in the project's status lifecycle
# (run resolve-statuses.sh to list valid names).
#
# Skips the write when the issue is already in the requested status, so repeated
# runs don't add redundant "changed status" system notes to the issue.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# First positional is the ref, second is the status name; -R may follow.
ref="${1:-}"
status_name="${2:-}"
[[ -n "$ref" && -n "$status_name" ]] || die "usage: set-issue-status.sh <issue-url|iid> <status-name> [-R owner/repo]"
shift 2

parse_issue_ref "$ref" "$@"

# No-op guard: if the status already matches, skip the mutation entirely.
# Comparison is case-insensitive because the caller passes a human-typed name.
current="$(current_status_json)"
if [[ -n "$current" ]] &&
  [[ "$(jq -r '.name | ascii_downcase' <<<"$current")" == "$(printf '%s' "$status_name" | tr '[:upper:]' '[:lower:]')" ]]; then
  echo "${PROJECT_PATH}#${ISSUE_IID} already ${status_name}; no change"
  exit 0
fi

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

# A failed GraphQL call (auth, malformed query, network) returns top-level
# `errors` with `data: null`; check that first so the failure is legible
# instead of a jq type error on `null | join`.
top_errors="$(jq -r 'if .errors then (.errors | map(.message) | join("; ")) else "" end' <<<"$result")"
[[ -z "$top_errors" ]] || die "GraphQL error: $top_errors"

errors="$(jq -r '.data.workItemUpdate.errors | join("; ")' <<<"$result")"
[[ -z "$errors" ]] || die "workItemUpdate failed: $errors"

new_status="$(jq -r '.data.workItemUpdate.workItem.widgets[] | select(.status) | .status.name' <<<"$result")"
echo "${PROJECT_PATH}#${ISSUE_IID} status -> ${new_status}"
