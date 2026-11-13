#!/usr/bin/env zsh

emulate -LR zsh
setopt err_return pipefail
root=${0:A:h:h:h:h:h}
temporary=$(mktemp -d "${TMPDIR:-/tmp}/sesh-list.XXXXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
fail() { print -ru2 -- "$*"; exit 1; }

mkdir -p "$temporary/bin" "$temporary/home/Developer/github.com/pedropombeiro"/{existing,new-project,'space project'}/nested
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
[[ $SESH_TEST_FAIL == true ]] && exit 7
[[ $SESH_TEST_INVALID == true ]] && { printf 'invalid json\n'; exit; }
jq -n --arg home "$HOME" '[
  {Src: "tmux", Name: "active", Path: ($home + "/Developer/github.com/pedropombeiro/existing"), TmuxWindows: [{Name: "editor window", Active: true}]},
  {Src: "tmux", Name: "another-session", Path: ($home + "/Developer/github.com/pedropombeiro/existing")},
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

for flags in '' '--icons'; do
  output=$("$helper" ${=flags})
  [[ $output == *'~/Developer/github.com/pedropombeiro/new-project'* ]] || fail "Project missing: $flags"
  [[ $output == *'~/Developer/github.com/pedropombeiro/space project'* ]] || fail "Space in project name lost: $flags"
  [[ $output != *nested* ]] || fail "Nested directories included: $flags"
  [[ $output != *'/existing'* ]] || fail "Running project duplicated as a directory: $flags"
  [[ $output == *another-session* ]] || fail "Sessions sharing a path were hidden: $flags"
  [[ $output == *'[editor window]'* ]] || fail "Active window missing: $flags"
  [[ $output == *'config with spaces'* ]] || fail "Session name with spaces lost: $flags"
  [[ $output == *$'\e[38;5;214m●'* ]] || fail "Waiting marker missing: $flags"
  print -r -- "$output" | awk -F '\t' 'NF != 3 { exit 1 }' || fail "Invalid picker fields: $flags"
  print -r -- "$output" | awk -F '\t' '$1 != $2 || $1 ~ /📁|\033/ { exit 1 }' || fail "Display icon leaked into connect/preview input: $flags"
done
for flags in -t -z -T -p -c -tc '-t -c' '--config --icons' --config --tmux --zoxide --tmuxinator --panes; do
  output=$("$helper" ${=flags})
  [[ $output != *new-project* ]] || fail "Projects leaked into source filter: $flags"
done
SESH_TEST_FAIL=true "$helper" >/dev/null && fail 'sesh failure was hidden'
SESH_TEST_INVALID=true "$helper" >/dev/null 2>&1 && fail 'Invalid JSON was accepted'
export HOME="$temporary/missing-home"
output=$("$helper")
[[ $output != *'/*'* ]] || fail 'Missing project root produced a literal glob'
print -r -- 'Sesh project discovery, source filters, deduplication, and waiting markers: passed'
