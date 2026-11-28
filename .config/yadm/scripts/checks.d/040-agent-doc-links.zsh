#!/usr/bin/env zsh

set -o pipefail
setopt EXTENDED_GLOB
source "${${(%):-%x}:A:h:h}/lib/check-helpers.zsh"

# Slugify a markdown heading line the way GitHub/GitLab anchors do: strip the
# leading #s, lowercase, drop everything but alphanumerics/spaces/hyphens, then
# spaces to hyphens.
function _slugify_heading() {
  local h="$1"
  h="${h##\###[[:space:]]#}"
  h="${(L)h}"
  h="${h//[^a-z0-9 -]/}"
  echo "${h// /-}"
}

# Collect the files a relative doc link can point at: the target itself, plus
# the YADM alternates that render it on the machines they apply to. YADM keeps
# an alternate next to the target it renders, such as
# `gdkbox-gcp.md##class.Work,extension.md`, so a doc that links to a
# class-gated file stays valid on machines where that alternate isn't rendered.
function _doc_target_candidates() {
  local dir="$1" target="$2"
  local -a result
  local target_dir="${target:h}"
  [[ "$target_dir" == "." ]] && target_dir=""
  [[ -f "$dir/$target" ]] && result+=("$dir/$target")
  local prefix="${target:t}##" candidate
  for candidate in "$dir/$target_dir"/*(N); do
    [[ "${candidate:t}" == "$prefix"* ]] && result+=("$candidate")
  done
  reply=("${result[@]}")
}

# Relative links between agent docs are invisible to every linter we run, so a
# renamed heading or moved file rots silently until an agent follows the link.
function check_agent_doc_links() {
  print_op_stay "Checking ~/.agents/docs links and anchors"

  local docs_dir="$HOME/.agents/docs"
  if [[ ! -d "$docs_dir" ]]; then
    print_ok "(skipped, no docs dir)"
    return
  fi

  local -a broken
  local f dir m link target anchor heading found candidate
  local -a candidates
  for f in "$docs_dir"/**/*.md(N); do
    dir="${f:h}"
    for m in ${(f)"$(grep -oE '\]\([^)]+\.md(#[A-Za-z0-9._-]+)?\)' "$f" 2>/dev/null)"}; do
      link="${m#\]\(}"
      link="${link%\)}"
      # Only relative links are ours to validate; skip URLs and absolute paths.
      case "$link" in http*|'~'*|/*) continue ;; esac

      target="${link%%\#*}"
      anchor=""
      [[ "$link" == *'#'* ]] && anchor="${link#*\#}"

      candidates=()
      _doc_target_candidates "$dir" "$target"
      candidates=("${reply[@]}")

      if (( ! ${#candidates} )); then
        broken+=("${f:t} -> $link (no such file)")
        continue
      fi

      [[ -n "$anchor" ]] || continue
      found=0
      for candidate in "${candidates[@]}"; do
        while IFS= read -r heading; do
          if [[ "$(_slugify_heading "$heading")" == "$anchor" ]]; then
            found=1
            break
          fi
        done < <(grep -E '^#{1,6} ' "$candidate")
        (( found )) && break
      done
      (( found )) || broken+=("${f:t} -> $link (no such heading)")
    done
  done

  if (( ${#broken} == 0 )); then
    print_ok
  else
    echo
    local b
    for b in "${broken[@]}"; do
      print_warn "$b"
    done
  fi
}

check_agent_doc_links
exit "$any_failed"
