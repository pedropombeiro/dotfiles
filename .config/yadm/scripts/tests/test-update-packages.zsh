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
print 'PASS: package snapshots, version comparisons, and failed listings'
