#!/usr/bin/env bash
# Shared helpers for the issue-state skill.
# Not executable on its own; sourced by the other scripts.

set -euo pipefail

# glab authenticates via a 1Password shell plugin. In interactive shells `glab`
# is an alias for `op plugin run -- glab`; scripts don't get that alias, and a
# bare `glab` binary (if present) has no valid token. So prefer the op wrapper
# whenever `op` is available, and only fall back to a bare `glab` binary.
# Override with GLAB_CMD if your setup differs.
_glab_cmd=""
glab() {
  if [[ -z "$_glab_cmd" ]]; then
    if [[ -n "${GLAB_CMD:-}" ]]; then
      _glab_cmd="$GLAB_CMD"
    elif command -v op >/dev/null 2>&1; then
      _glab_cmd="op plugin run -- glab"
    elif command -v glab >/dev/null 2>&1; then
      _glab_cmd="glab"
    else
      echo "error: glab not found (neither via 'op plugin run' nor on PATH)" >&2
      return 127
    fi
  fi
  # shellcheck disable=SC2086
  ${_glab_cmd} "$@"
}

die() {
  echo "error: $*" >&2
  exit 1
}

# Parse an issue/work-item reference into PROJECT_PATH and ISSUE_IID.
# Accepts either:
#   - a full URL: https://gitlab.com/group/sub/project/-/issues/123
#                 https://gitlab.com/group/sub/project/-/work_items/123
#   - an IID plus -R/--repo <owner/repo>: 123 -R group/project
# Exports: PROJECT_PATH (raw, unencoded) and ISSUE_IID.
parse_issue_ref() {
  local ref="${1:-}"
  shift || true
  local repo=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R | --repo)
        repo="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done

  [[ -n "$ref" ]] || die "missing issue reference (URL or IID)"

  if [[ "$ref" == http*://* ]]; then
    # Strip scheme+host, then split on /-/issues|work_items/
    local path="${ref#*://}"
    path="${path#*/}" # drop host
    if [[ "$path" =~ ^(.+)/-/(issues|work_items)/([0-9]+) ]]; then
      PROJECT_PATH="${BASH_REMATCH[1]}"
      ISSUE_IID="${BASH_REMATCH[3]}"
    else
      die "could not parse project/iid from URL: $ref"
    fi
  else
    [[ "$ref" =~ ^[0-9]+$ ]] || die "expected numeric IID or a URL, got: $ref"
    [[ -n "$repo" ]] || die "IID given without -R <owner/repo>"
    ISSUE_IID="$ref"
    PROJECT_PATH="$repo"
  fi

  export PROJECT_PATH ISSUE_IID
}

# URL-encode a project path for REST calls (/ -> %2F).
enc_path() {
  printf '%s' "$1" | sed 's#/#%2F#g'
}

# Resolve the GraphQL global ID for an issue (work item).
# Requires PROJECT_PATH and ISSUE_IID to be set.
work_item_gid() {
  glab api graphql -f query="
{
  project(fullPath: \"${PROJECT_PATH}\") {
    workItems(first: 1, iid: \"${ISSUE_IID}\") { nodes { id } }
  }
}" | jq -r '.data.project.workItems.nodes[0].id // empty'
}
