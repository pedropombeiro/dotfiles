#!/usr/bin/env bash
# List the status lifecycle available to a work item, or resolve a status name to its ID.
#
# Usage:
#   resolve-statuses.sh <issue-url>
#   resolve-statuses.sh <iid> -R <owner/repo>
#   resolve-statuses.sh <issue-url> --name "In dev"     # print just the matching status ID
#
# Without --name: prints a JSON array of {id, name, category} for every allowed status.
# With --name: prints the single global ID whose name matches (case-insensitive), or exits 1.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

name_filter=""
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      name_filter="$2"
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

parse_issue_ref "${args[@]}"

statuses_json="$(glab api graphql -f query="
{
  project(fullPath: \"${PROJECT_PATH}\") {
    workItems(first: 1, iid: \"${ISSUE_IID}\") {
      nodes {
        workItemType {
          widgetDefinitions {
            ... on WorkItemWidgetDefinitionStatus {
              allowedStatuses { id name category }
            }
          }
        }
      }
    }
  }
}" | jq -c '
  [ .data.project.workItems.nodes[0].workItemType.widgetDefinitions[]?
    | select(.allowedStatuses != null)
    | .allowedStatuses[] ]')"

if [[ -z "$statuses_json" || "$statuses_json" == "[]" || "$statuses_json" == "null" ]]; then
  die "no status lifecycle found for ${PROJECT_PATH}#${ISSUE_IID} (Status may be unavailable on this tier/namespace)"
fi

if [[ -n "$name_filter" ]]; then
  id="$(jq -r --arg n "$name_filter" \
    'map(select(.name | ascii_downcase == ($n | ascii_downcase))) | .[0].id // empty' \
    <<<"$statuses_json")"
  [[ -n "$id" ]] || die "no status named '$name_filter' in this lifecycle. Run without --name to list options."
  printf '%s\n' "$id"
else
  jq '.' <<<"$statuses_json"
fi
