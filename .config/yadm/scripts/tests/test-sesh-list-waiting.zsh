#!/usr/bin/env zsh

emulate -LR zsh
setopt err_return pipefail
root=${0:A:h:h:h:h:h}
temporary=$(mktemp -d "${TMPDIR:-/tmp}/sesh-list.XXXXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
fail() { print -ru2 -- "$*"; exit 1; }

mkdir -p "$temporary/bin" "$temporary/home/Developer/github.com/pedropombeiro"/{existing,new-project,'space project'}/nested
mkdir -p "$temporary/home/Developer/github.com/pedropombeiro"/{existing,new-project,'space project'}/.git
mkdir -p "$temporary/home/Developer/github.com/another-owner/other-project/.git"
mkdir -p "$temporary/home/Developer/gitlab.com/gitlab-org/ai/nested-project/.git"
mkdir -p "$temporary/home/Developer/gitlab.com/team/worktree"
print -r -- 'gitdir: /unused/fixture' > "$temporary/home/Developer/gitlab.com/team/worktree/.git"
mkdir -p "$temporary/home/Developer/gitlab.com/team/not-a-repo"
mkdir -p "$temporary/home/Developer/github.com/pedropombeiro/new-project/nested/embedded/.git"
ln -s "$temporary/home/Developer" "$temporary/home/Developer/loop"
# Resolve mise-managed tools before HOME changes to the fixture directory.
for jq_path in ${(f)$(whence -pa jq)} /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
  [[ $jq_path == */mise/shims/* ]] && continue
  [[ -x $jq_path ]] || continue
  ln -s "$jq_path" "$temporary/bin/jq"
  break
done
[[ -x "$temporary/bin/jq" ]] || fail 'A non-shim jq executable is required for fixture tests'
cat > "$temporary/bin/sesh" <<'EOF'
#!/bin/bash
for arg in "$@"; do
  [[ $arg == --projects ]] && exit 9
done
[[ $SESH_TEST_FAIL == true ]] && exit 7
[[ $SESH_TEST_INVALID == true ]] && { printf 'invalid json\n'; exit; }
jq -n --arg home "$HOME" '[
  {Src: "tmux", Name: "active", Path: ($home + "/Developer/github.com/pedropombeiro/existing"), TmuxWindows: [{Name: "editor window", Active: true}]},
  {Src: "tmux", Name: "another-session", Path: ($home + "/Developer/github.com/pedropombeiro/existing")},
  {Src: "tmux", Name: "unrelated-session", Path: $home},
  {Src: "zoxide", Name: ($home + "/Developer/github.com/pedropombeiro/existing"), Path: ($home + "/Developer/github.com/pedropombeiro/existing")},
  {Src: "config", Name: "config with spaces", Path: ($home + "/Developer/github.com/pedropombeiro/existing"), Icon: "🔧"}
]'
EOF
cat > "$temporary/bin/tmux" <<'EOF'
#!/bin/bash
printf 'active\n'
EOF
chmod +x "$temporary/bin/"{sesh,tmux}
export HOME="$temporary/home" PATH="$temporary/bin:$PATH"
helper="$root/.local/bin/sesh-list-waiting"

for flags in '' '--icons' '--projects' '--projects --icons'; do
  output=$("$helper" ${=flags})
  [[ $output == *'~/Developer/github.com/pedropombeiro/new-project'* ]] || fail "Project missing: $flags"
  [[ $output == *'~/Developer/github.com/pedropombeiro/space project'* ]] || fail "Space in project name lost: $flags"
  [[ $output == *'~/Developer/github.com/another-owner/other-project'* ]] || fail "Other GitHub owner missing: $flags"
  [[ $output == *'~/Developer/gitlab.com/gitlab-org/ai/nested-project'* ]] || fail "Nested GitLab project missing: $flags"
  [[ $output == *'~/Developer/gitlab.com/team/worktree'* ]] || fail "Git worktree missing: $flags"
  [[ $output != *not-a-repo* ]] || fail "Non-repository directory included: $flags"
  [[ $output != *'/nested/'* ]] || fail "Repository contents scanned: $flags"
  [[ $output != *'/loop/'* ]] || fail "Directory symlink followed: $flags"
  [[ $output != *'/existing'* ]] || fail "Running project duplicated as a directory: $flags"
  [[ $output == *another-session* ]] || fail "Sessions sharing a path were hidden: $flags"
  [[ $output == *'[editor window]'* ]] || fail "Active window missing: $flags"
  if [[ $flags != *--projects* ]]; then
    [[ $output == *'config with spaces'* ]] || fail "Session name with spaces lost: $flags"
  fi
  [[ $output == *$'\e[38;5;214m●'* ]] || fail "Waiting marker missing: $flags"
  print -r -- "$output" | awk -F '\t' 'NF != 3 { exit 1 }' || fail "Invalid picker fields: $flags"
  print -r -- "$output" | awk -F '\t' '$1 != $2 || $1 ~ /📁|\033/ { exit 1 }' || fail "Display icon leaked into connect/preview input: $flags"
done
output=$("$helper" --projects)
[[ $output != *unrelated-session* ]] || fail 'Unrelated tmux session included in projects view'
[[ $output != *'config with spaces'* ]] || fail 'Config session included in projects view'
[[ $output == *active* && $output == *another-session* ]] || fail 'Running project sessions missing from projects view'
for flags in -t -z -T -p -c -tc '-t -c' '--config --icons' --config --tmux --zoxide --tmuxinator --panes; do
  output=$("$helper" ${=flags})
  [[ $output != *new-project* && $output != *nested-project* && $output != *worktree* ]] || fail "Projects leaked into source filter: $flags"
done
SESH_TEST_FAIL=true "$helper" >/dev/null && fail 'sesh failure was hidden'
SESH_TEST_INVALID=true "$helper" >/dev/null 2>&1 && fail 'Invalid JSON was accepted'
export HOME="$temporary/missing-home"
output=$("$helper")
[[ $output != *'/*'* ]] || fail 'Missing project root produced a literal glob'
output=$("$helper" --projects)
[[ -z $output ]] || fail 'Missing project root produced project rows'
print -r -- 'Sesh project discovery, source filters, deduplication, and waiting markers: passed'
