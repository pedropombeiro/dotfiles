#!/usr/bin/env bash
# Resolve a merge request from the current branch, a URL, or an IID.
#
# Usage:
#   resolve-mr.sh                # infer from current branch
#   resolve-mr.sh <MR_IID>       # IID in the current repo
#   resolve-mr.sh <MR_URL>       # full gitlab.com MR URL
#   resolve-mr.sh <IID> -R owner/repo
#
# Emits a single JSON object on stdout:
#   { "project": "<owner/repo>", "iid": <n>, "author": "<username>",
#     "title": "<title>", "files": ["path", ...] }
#
# Requires: glab (authenticated), jq.
set -euo pipefail

die() {
  echo "resolve-mr: $*" >&2
  exit 1
}

command -v glab >/dev/null || die "glab not found"
command -v jq >/dev/null || die "jq not found"

ARG="${1:-}"
REPO=""
IID=""

# Parse optional -R owner/repo
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "-R" ]]; then
    REPO="${args[$((i + 1))]:-}"
  fi
done

if [[ -z "$ARG" || "$ARG" == "-R" ]]; then
  # Infer from current branch via glab.
  view_json="$(glab mr view -F json 2>/dev/null)" || die "no MR found for current branch; pass an IID or URL"
  IID="$(jq -r '.iid' <<<"$view_json")"
  [[ -n "$REPO" ]] || REPO="$(jq -r '.web_url' <<<"$view_json" | sed -E 's#https?://[^/]+/(.+)/-/merge_requests/.*#\1#')"
elif [[ "$ARG" =~ ^https?:// ]]; then
  # Full URL: https://host/owner/repo/-/merge_requests/IID
  REPO="$(sed -E 's#https?://[^/]+/(.+)/-/merge_requests/[0-9]+.*#\1#' <<<"$ARG")"
  IID="$(sed -E 's#.*/merge_requests/([0-9]+).*#\1#' <<<"$ARG")"
else
  IID="$ARG"
  if [[ -z "$REPO" ]]; then
    REPO="$(glab repo view -F json 2>/dev/null | jq -r '.full_name // empty')" || true
  fi
fi

[[ -n "$IID" ]] || die "could not determine MR IID"
[[ -n "$REPO" ]] || die "could not determine repository (pass -R owner/repo)"

enc_repo="${REPO//\//%2F}"

mr_json="$(glab api "projects/${enc_repo}/merge_requests/${IID}")" ||
  die "failed to fetch MR ${REPO}!${IID}"

changes_json="$(glab api "projects/${enc_repo}/merge_requests/${IID}/changes?access_raw_diffs=false")" ||
  die "failed to fetch MR changes"

jq -n \
  --argjson mr "$mr_json" \
  --argjson ch "$changes_json" \
  --arg repo "$REPO" \
  '{
    project: $repo,
    iid: $mr.iid,
    author: $mr.author.username,
    title: $mr.title,
    files: ($ch.changes // [] | map(.new_path // .old_path) | unique)
  }'
