#!/usr/bin/env zsh

emulate -LR zsh
setopt err_return pipefail
root=${0:A:h:h:h:h:h}
temporary=$(mktemp -d "${TMPDIR:-/tmp}/sesh-list.XXXXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
fail() { print -ru2 -- "$*"; exit 1; }

mkdir -p "$temporary/bin" "$temporary/home/Developer/github.com/pedropombeiro"/{existing,new-project,'space project'}/nested
cat > "$temporary/bin/sesh" <<'EOF'
#!/bin/bash
[[ $SESH_TEST_FAIL == true ]] && exit 7
prefix=''
for arg in "$@"; do
  [[ $arg == --icons ]] && prefix='📁 '
done
printf '%sactive\n' "$prefix"
printf '%s%s/Developer/github.com/pedropombeiro/existing\n' "$prefix" "$HOME"
EOF
cat > "$temporary/bin/tmux" <<'EOF'
#!/bin/bash
printf 'active\n'
EOF
chmod +x "$temporary/bin/"{sesh,tmux}
export HOME="$temporary/home" PATH="$temporary/bin:$PATH"
helper="$root/.local/bin/sesh-list-waiting"

for flags in '' '--icons' '-c' '-tc' '-t -c'; do
  output=$("$helper" ${=flags})
  [[ $output == *'~/Developer/github.com/pedropombeiro/new-project'* ]] || fail "Project missing: $flags"
  [[ $output == *'~/Developer/github.com/pedropombeiro/space project'* ]] || fail "Space in project name lost: $flags"
  [[ $output != *nested* ]] || fail "Nested directories included: $flags"
  [[ $(print -r -- "$output" | grep -c '/existing') == 1 ]] || fail "Duplicate project: $flags"
  [[ $output == *$'\e[38;5;214m●'* ]] || fail "Waiting marker missing: $flags"
  print -r -- "$output" | awk -F '\t' 'NF != 3 { exit 1 }' || fail "Invalid picker fields: $flags"
  print -r -- "$output" | awk -F '\t' '$1 != $2 || $1 ~ /📁|\033/ { exit 1 }' || fail "Display icon leaked into connect/preview input: $flags"
done
for flag in -t -z -T -p --tmux --zoxide --tmuxinator --panes; do
  output=$("$helper" "$flag")
  [[ $output != *new-project* ]] || fail "Projects leaked into source filter: $flag"
done
SESH_TEST_FAIL=true "$helper" >/dev/null && fail 'sesh failure was hidden'
export HOME="$temporary/missing-home"
output=$("$helper")
[[ $output != *'/*'* ]] || fail 'Missing project root produced a literal glob'
print -r -- 'Sesh project discovery, source filters, deduplication, and waiting markers: passed'
