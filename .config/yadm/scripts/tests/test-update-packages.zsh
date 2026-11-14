#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit
source "${0:A:h:h}/lib/update-packages.zsh"
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/update-packages-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
fail() { print -ru2 -- "FAIL: $*"; exit 1; }
_ui_snapshot_dir=$sandbox
_ui_managers=(fixture unavailable)
_ui_upgraded=() _ui_installed=() _ui_removed=()
_ui_versions_fixture() { print -r -- "$fixture_versions"; }
_ui_versions_unavailable() { print partial; return 1; }
fixture_versions=$'changed\t1\nremoved\t2\nunchanged\t3'
_ui_snapshot before
fixture_versions=$'changed\t4\ninstalled\t5\nunchanged\t3'
_ui_snapshot after
[[ ! -f "$sandbox/before/unavailable" && ! -f "$sandbox/after/unavailable" ]] || fail 'partial listing retained'
_ui_diff fixture
[[ $_ui_upgraded[1] == $'fixture\tchanged\t1 → 4' ]] || fail 'upgrade comparison'
[[ $_ui_installed[1] == $'fixture\tinstalled\t5' ]] || fail 'install comparison'
[[ $_ui_removed[1] == $'fixture\tremoved\t2' ]] || fail 'removal comparison'
rm "$sandbox/after/fixture"
_ui_diff fixture
[[ ${#_ui_removed} == 1 ]] || fail 'missing listing created false removals'
_ui_skill_lockfile=$sandbox/skill-lock.json
_ui_versions_skills > /dev/null 2>&1 && fail 'missing skill lock file listed'
print -r -- '{"skills":{"beta":{"skillFolderHash":"0123456789abcdef"},"alpha":{"skillFolderHash":"fedcba9876543210"}}}' > "$_ui_skill_lockfile"
[[ $(_ui_versions_skills) == $'beta\t0123456\nalpha\tfedcba9' ]] || fail 'skill lock file listing'
commit() {
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false \
    commit -q --allow-empty -m "$2"
  git -C "$1" rev-parse --short=7 HEAD
}
repo() { git init -q "$1" && commit "$1" initial; }
_ui_zinit_dir=$sandbox/zinit
_ui_versions_zinit > /dev/null 2>&1 && fail 'missing zinit directory listed'
zinit_sha=$(repo "$_ui_zinit_dir/zinit.git")
plugin_old=$(repo "$_ui_zinit_dir/plugins/owner---repo")
mkdir -p "$_ui_zinit_dir/plugins/_local---zinit"
[[ $(_ui_versions_zinit) == "zinit"$'\t'"$zinit_sha"$'\n'"owner/repo"$'\t'"$plugin_old" ]] ||
  fail 'zinit checkout listing'
commit "$_ui_zinit_dir/plugins/owner---repo" second > /dev/null
plugin_new=$(commit "$_ui_zinit_dir/plugins/owner---repo" third)
[[ $(_ui_detail_zinit owner/repo "$plugin_old" "$plugin_new") == ' (2 commits)' ]] || fail 'zinit commit count'
[[ $(_ui_detail_zinit owner/repo "$plugin_new" "$plugin_old") == ' (rolled back)' ]] || fail 'zinit rollback'
print 'PASS: package snapshots, version comparisons, failed listings, skill hashes, and git checkouts'
