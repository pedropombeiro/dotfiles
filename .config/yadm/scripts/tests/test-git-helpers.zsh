#!/usr/bin/env zsh

# Regression tests for stacked branch resolution in git-helpers.rb.
emulate -LR zsh
setopt err_return pipefail

root=${0:A:h:h:h:h:h}
helper="$root/.shellrc/zshrc.d/functions/scripts/git-helpers.rb"
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/git-helpers-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT

export GIT_AUTHOR_NAME='Test User'
export GIT_AUTHOR_EMAIL='test@example.com'
export GIT_COMMITTER_NAME='Test User'
export GIT_COMMITTER_EMAIL='test@example.com'
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export USER=tester

fail() {
  print -ru2 -- "FAIL: $*"
  exit 1
}

typeset -a ruby_cmd
if (( $+commands[ruby] )) && ruby -e 'exit((RUBY_VERSION.split(".").map(&:to_i) <=> [3, 2]) >= 0 ? 0 : 1)' 2>/dev/null; then
  ruby_cmd=(ruby)
elif (( $+commands[mise] )); then
  ruby_cmd=(mise x ruby -- ruby)
else
  fail 'requires Ruby >= 3.2 or mise'
fi

init_repo() {
  local repo=$1
  mkdir -p "$repo"
  git -C "$repo" init -q -b master
  git -C "$repo" config commit.gpgsign false
  git -C "$repo" config core.hooksPath /dev/null
  print -r -- 'base' > "$repo/base.txt"
  git -C "$repo" add base.txt
  git -C "$repo" commit -q -m 'Initial commit'
}

add_commit() {
  local repo=$1 file=$2 content=$3 msg=$4
  print -r -- "$content" > "$repo/$file"
  git -C "$repo" add "$file"
  git -C "$repo" commit -q -m "$msg"
}

run_mappings() {
  local repo=$1
  (
    cd "$repo"
    "${ruby_cmd[@]}" -r json -r "$helper" -e 'puts JSON.generate(rebase_mappings)'
  )
}

run_rebase_all() {
  local repo=$1
  (
    cd "$repo"
    "${ruby_cmd[@]}" -r "$helper" -e 'rebase_all'
  )
}

# 1. Direct-ancestor unnumbered base branch
repo="$sandbox/direct-ancestor"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/100/base
add_commit "$repo" base_feat.txt 'feat 1' 'Add base feature'
base_sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q -b tester/100/2-child
add_commit "$repo" child_feat.txt 'feat 2' 'Add child feature'

json=$(run_mappings "$repo")
onto=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/100/2-child") | .rebase_onto')
fp=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/100/2-child") | .fork_point')
[[ $onto == 'tester/100/base' && $fp == "$base_sha" ]] || fail "direct ancestor: onto=$onto fp=$fp expected=$base_sha"
print -r -- 'PASS: direct-ancestor unnumbered base'

# 2. Reflog fork-point rewritten unnumbered base branch
repo="$sandbox/reflog-rewritten"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/101/base
add_commit "$repo" base_feat.txt 'v1' 'Add base feature'
old_base_sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q -b tester/101/2-child
add_commit "$repo" child_feat.txt 'child' 'Add child feature'
git -C "$repo" checkout -q tester/101/base
add_commit "$repo" base_feat.txt 'v2' 'Amend base feature'
git -C "$repo" reset --soft HEAD~1
git -C "$repo" commit -q --amend -m 'Add base feature (amended)'

json=$(run_mappings "$repo")
onto=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/101/2-child") | .rebase_onto')
fp=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/101/2-child") | .fork_point')
[[ $onto == 'tester/101/base' && $fp == "$old_base_sha" ]] || fail "reflog rewritten: onto=$onto fp=$fp expected=$old_base_sha"
print -r -- 'PASS: reflog fork-point rewritten unnumbered base'

# 3. Patch-equivalent rewritten unnumbered base when reflog does not resolve (gitlab#641750)
repo="$sandbox/patch-equiv-unnumbered"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/102/base
add_commit "$repo" base_feat.txt 'runtime bundle' 'Add runtime bundles'
git -C "$repo" checkout -q -b tester/102/2-child
add_commit "$repo" child1.txt 'doc 1' 'Use runtime bundle'
add_commit "$repo" child2.txt 'doc 2' 'Align docs'
git -C "$repo" checkout -q master
add_commit "$repo" master1.txt 'm2' 'Advance master to M2'
# Independently rebase both onto M2 with distinct committer timestamps so commit SHAs differ
GIT_COMMITTER_DATE='2026-11-20T10:01:00Z' git -C "$repo" rebase -q master tester/102/base
GIT_COMMITTER_DATE='2026-11-20T10:02:00Z' git -C "$repo" rebase -q master tester/102/2-child
child_parent_copy=$(git -C "$repo" rev-parse tester/102/2-child~2)
git -C "$repo" merge-base --is-ancestor tester/102/base tester/102/2-child && \
  fail 'patch-equiv unnumbered setup: base should not be a direct ancestor of child'

json=$(run_mappings "$repo")
onto=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/102/2-child") | .rebase_onto')
fp=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/102/2-child") | .fork_point')
ambig=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/102/2-child") | .ambiguous_parents')
[[ $onto == 'tester/102/base' && $fp == "$child_parent_copy" && $ambig == 'null' ]] || \
  fail "patch-equiv unnumbered: onto=$onto fp=$fp expected=$child_parent_copy ambig=$ambig"

# Advance master again and verify rebase_all restores stack without duplicating parent patch
git -C "$repo" checkout -q master
add_commit "$repo" master2.txt 'm3' 'Advance master to M3'
run_rebase_all "$repo" >/dev/null
git -C "$repo" merge-base --is-ancestor tester/102/base tester/102/2-child || \
  fail 'patch-equiv unnumbered: base is not ancestor of child after rebase_all'
base_count=$(git -C "$repo" rev-list --count master..tester/102/base)
child_only_count=$(git -C "$repo" rev-list --count tester/102/base..tester/102/2-child)
[[ $base_count == '1' && $child_only_count == '2' ]] || \
  fail "patch-equiv unnumbered after rebase_all: base_count=$base_count child_only_count=$child_only_count"
print -r -- 'PASS: patch-equivalent rewritten unnumbered base + rebase_all'

# 4. Patch-equivalent rewritten sequenced parent (1- -> 2-) when reflog does not resolve
repo="$sandbox/patch-equiv-sequenced"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/103/1-first
add_commit "$repo" first.txt 'first' 'First commit'
git -C "$repo" checkout -q -b tester/103/2-second
add_commit "$repo" second.txt 'second' 'Second commit'
git -C "$repo" checkout -q master
add_commit "$repo" master1.txt 'm2' 'Advance master to M2'
GIT_COMMITTER_DATE='2026-11-20T10:01:00Z' git -C "$repo" rebase -q master tester/103/1-first
GIT_COMMITTER_DATE='2026-11-20T10:02:00Z' git -C "$repo" rebase -q master tester/103/2-second
child_parent_copy=$(git -C "$repo" rev-parse tester/103/2-second~1)
git -C "$repo" merge-base --is-ancestor tester/103/1-first tester/103/2-second && \
  fail 'patch-equiv sequenced setup: parent should not be a direct ancestor of child'

json=$(run_mappings "$repo")
onto=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/103/2-second") | .rebase_onto')
fp=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/103/2-second") | .fork_point')
[[ $onto == 'tester/103/1-first' && $fp == "$child_parent_copy" ]] || \
  fail "patch-equiv sequenced: onto=$onto fp=$fp expected=$child_parent_copy"
print -r -- 'PASS: patch-equivalent rewritten sequenced parent'

# 5. Ambiguous patch-equivalent unnumbered candidates skip instead of choosing master
repo="$sandbox/ambiguous-stack"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/104/base-a
add_commit "$repo" shared.txt 'same patch' 'Shared parent patch'
git -C "$repo" checkout -q -b tester/104/2-child
add_commit "$repo" child.txt 'child' 'Child patch'
git -C "$repo" checkout -q master
add_commit "$repo" master1.txt 'm2' 'Advance master to M2'
git -C "$repo" checkout -q -b tester/104/base-b
GIT_COMMITTER_DATE='2026-11-20T10:00:00Z' add_commit "$repo" shared.txt 'same patch' 'Shared parent patch copy'
GIT_COMMITTER_DATE='2026-11-20T10:01:00Z' git -C "$repo" rebase -q master tester/104/base-a
GIT_COMMITTER_DATE='2026-11-20T10:02:00Z' git -C "$repo" rebase -q master tester/104/2-child
git -C "$repo" merge-base --is-ancestor tester/104/base-a tester/104/2-child && \
  fail 'ambiguous stack setup: base-a should not be a direct ancestor of child'
git -C "$repo" merge-base --is-ancestor tester/104/base-b tester/104/2-child && \
  fail 'ambiguous stack setup: base-b should not be a direct ancestor of child'
before_child_sha=$(git -C "$repo" rev-parse tester/104/2-child)

json=$(run_mappings "$repo")
ambig_count=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/104/2-child") | .ambiguous_parents | length')
[[ $ambig_count == '2' ]] || fail "ambiguous stack: expected 2 ambiguous_parents, got $ambig_count ($json)"

git -C "$repo" checkout -q master
add_commit "$repo" master2.txt 'm3' 'Advance master to M3'
output=$(run_rebase_all "$repo")
after_child_sha=$(git -C "$repo" rev-parse tester/104/2-child)
[[ $before_child_sha == "$after_child_sha" ]] || fail 'ambiguous stack: child branch should have been skipped'
[[ $output == *'ambiguous stack parent'* ]] || fail "ambiguous stack: missing warning in output: $output"
print -r -- 'PASS: ambiguous patch-equivalent stack flagged and skipped'

# 6. Parent with more commits than child is still rebased before child
repo="$sandbox/topo-order"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/105/1-parent
add_commit "$repo" p1.txt 'p1' 'Parent commit 1'
git -C "$repo" checkout -q -b tester/105/2-child
add_commit "$repo" c1.txt 'c1' 'Child commit 1'
git -C "$repo" checkout -q tester/105/1-parent
add_commit "$repo" p2.txt 'p2' 'Parent commit 2'
add_commit "$repo" p3.txt 'p3' 'Parent commit 3'
git -C "$repo" checkout -q master
add_commit "$repo" master1.txt 'm2' 'Advance master to M2'

run_rebase_all "$repo" >/dev/null
git -C "$repo" merge-base --is-ancestor tester/105/1-parent tester/105/2-child || \
  fail 'topo order: parent is not ancestor of child after rebase_all'
git -C "$repo" merge-base --is-ancestor master tester/105/1-parent || \
  fail 'topo order: master is not ancestor of parent after rebase_all'
child_only_count=$(git -C "$repo" rev-list --count tester/105/1-parent..tester/105/2-child)
[[ $child_only_count == '1' ]] || fail "topo order: expected 1 child commit, got $child_only_count"
print -r -- 'PASS: topological rebase order (parent before shorter child)'

# 7. Multi-commit patch-equivalent rewritten parent that was squash-merged into master
repo="$sandbox/squash-merged-patch-equiv"
init_repo "$repo"
git -C "$repo" checkout -q -b tester/106/base
add_commit "$repo" p1.txt 'p1' 'Parent commit 1'
add_commit "$repo" p2.txt 'p2' 'Parent commit 2'
git -C "$repo" checkout -q -b tester/106/2-child
add_commit "$repo" c1.txt 'c1' 'Child commit 1'
git -C "$repo" checkout -q master
add_commit "$repo" master1.txt 'm2' 'Advance master to M2'
GIT_COMMITTER_DATE='2026-11-20T10:01:00Z' git -C "$repo" rebase -q master tester/106/base
GIT_COMMITTER_DATE='2026-11-20T10:02:00Z' git -C "$repo" rebase -q master tester/106/2-child
child_parent_copy=$(git -C "$repo" rev-parse tester/106/2-child~1)
git -C "$repo" merge-base --is-ancestor tester/106/base tester/106/2-child && \
  fail 'squash-merged patch-equiv setup: base should not be direct ancestor of child'
# Squash-merge base into master
git -C "$repo" checkout -q master
git -C "$repo" merge -q --squash tester/106/base
git -C "$repo" commit -q -m 'Squash merge base'

json=$(run_mappings "$repo")
onto=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/106/2-child") | .rebase_onto')
fp=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/106/2-child") | .fork_point')
base_squashed=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/106/base") | .squash_merged')
[[ $onto == 'master' && $fp == "$child_parent_copy" && $base_squashed == 'true' ]] || \
  fail "squash-merged patch-equiv: onto=$onto fp=$fp expected=$child_parent_copy base_squashed=$base_squashed"

run_rebase_all "$repo" >/dev/null
child_count=$(git -C "$repo" rev-list --count master..tester/106/2-child)
[[ $child_count == '1' ]] || fail "squash-merged patch-equiv after rebase_all: expected 1 commit, got $child_count"
print -r -- 'PASS: multi-commit patch-equivalent squash-merged parent'

# 8. Stale local branch behind upstream squash-merged with follow-up commits (work-friction#28)
repo="$sandbox/squash-merged-with-followups"
remote="$sandbox/squash-merged-with-followups-remote.git"
git init -q --bare -b master "$remote"
init_repo "$repo"
git -C "$repo" remote add origin "$remote"
add_commit "$repo" app.rb $'if cond\n  :ok\nelse\n  nil\nend' 'Add app.rb'
git -C "$repo" push -q -u origin master

git -C "$repo" checkout -q -b tester/107/remove-empty-else
GIT_COMMITTER_DATE='2026-11-25T10:00:00Z' add_commit "$repo" app.rb $'if cond\n  :ok\nend' 'Remove empty else'
local_stale_sha=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" push -q -u origin tester/107/remove-empty-else

# Follow-up commit on upstream edits the same lines before squash-merging into master
GIT_COMMITTER_DATE='2026-11-25T10:05:00Z' add_commit "$repo" app.rb $'# explain nil return\nif cond\n  :ok_v2\nend' 'Apply review suggestion'
git -C "$repo" push -q origin tester/107/remove-empty-else
git -C "$repo" reset -q --hard "$local_stale_sha"

git -C "$repo" checkout -q master
git -C "$repo" checkout -q -b squash-temp
git -C "$repo" merge -q --squash origin/tester/107/remove-empty-else
GIT_COMMITTER_DATE='2026-11-25T10:10:00Z' git -C "$repo" commit -q -m 'Remove empty else (squashed)'
git -C "$repo" checkout -q master
GIT_COMMITTER_DATE='2026-11-25T10:10:05Z' git -C "$repo" merge -q --no-ff squash-temp -m "Merge branch 'tester/107/remove-empty-else' into 'master'"
git -C "$repo" branch -D -q squash-temp

git -C "$repo" checkout -q -b tester/108/active-feature master~1
add_commit "$repo" active.txt 'active' 'Active feature'
git -C "$repo" checkout -q master
add_commit "$repo" master_next.txt 'next' 'Advance master'

json=$(run_mappings "$repo")
stale_squashed=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/107/remove-empty-else") | .squash_merged')
active_squashed=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/108/active-feature") | .squash_merged')
[[ $stale_squashed == 'true' && $active_squashed == 'false' ]] || \
  fail "squash-merged with follow-ups (live upstream): stale=$stale_squashed active=$active_squashed"

run_rebase_all "$repo" >/dev/null
after_stale_sha=$(git -C "$repo" rev-parse tester/107/remove-empty-else)
[[ $after_stale_sha == "$local_stale_sha" ]] || fail 'squash-merged with follow-ups: stale branch should have been skipped'
git -C "$repo" merge-base --is-ancestor master tester/108/active-feature || \
  fail 'squash-merged with follow-ups: active branch was not rebased onto master'
print -r -- 'PASS: stale local branch behind upstream squash-merged with follow-up commits'

# 9. Pruned upstream ([gone]) still detects verified merge commit unless new local work follows
git -C "$remote" branch -D -q tester/107/remove-empty-else
git -C "$repo" fetch -q --prune origin

json=$(run_mappings "$repo")
pruned_squashed=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/107/remove-empty-else") | .squash_merged')
[[ $pruned_squashed == 'true' ]] || fail "pruned upstream merge record: expected squash_merged=true, got $pruned_squashed"

git -C "$repo" checkout -q tester/107/remove-empty-else
GIT_COMMITTER_DATE='2026-11-25T10:20:00Z' add_commit "$repo" new_work.txt 'new work' 'Post-merge local commit'
json=$(run_mappings "$repo")
post_merge_squashed=$(print -r -- "$json" | jq -r '.[] | select(.branch == "tester/107/remove-empty-else") | .squash_merged')
[[ $post_merge_squashed == 'false' ]] || \
  fail "post-merge local work: expected squash_merged=false, got $post_merge_squashed"
print -r -- 'PASS: verified merge commit with pruned upstream and post-merge local work guard'
