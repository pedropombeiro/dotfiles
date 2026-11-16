#!/usr/bin/env zsh

emulate -LR zsh
setopt err_return pipefail
root=${0:A:h:h:h:h:h}
temporary=$(mktemp -d "${TMPDIR:-/tmp}/cheat.XXXXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
fail() { print -ru2 -- "$*"; exit 1; }

mkdir -p "$temporary/bin" "$temporary/config dir/glow" "$temporary/sheet dir"
export CHEAT_SHEETS_DIR="$temporary/sheet dir"
export XDG_CONFIG_HOME="$temporary/config dir"
export CHEAT_TEST_ARGS="$temporary/glow-args"
export CHEAT_TEST_SHEET=tmux CHEAT_TEST_STYLE=gruvbox.json
print '# Fixture' > "$CHEAT_SHEETS_DIR/tmux.md"
print '# Index' > "$CHEAT_SHEETS_DIR/README.md"
print '# OpenCode' > "$CHEAT_SHEETS_DIR/opencode.md"

cat > "$temporary/bin/dotfiles-theme" <<'EOF'
#!/bin/bash
[[ $* == 'value glow' ]] || exit 1
[[ $CHEAT_TEST_STYLE != missing ]] || exit 1
printf '%s\n' "$CHEAT_TEST_STYLE"
EOF
cat > "$temporary/bin/fzf" <<'EOF'
#!/bin/bash
cat >/dev/null
while (($#)); do
  if [[ $1 == --preview ]]; then
    preview=${2//\{\}/$CHEAT_TEST_SHEET}
    FZF_PREVIEW_COLUMNS=72 bash -c "$preview" > /dev/null || exit 1
    exit 130
  fi
  shift
done
exit 1
EOF
cat > "$temporary/bin/glow" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$CHEAT_TEST_ARGS"
EOF
chmod +x "$temporary/bin/"{dotfiles-theme,fzf,glow}
export PATH="$temporary/bin:$PATH"

for style in gruvbox.json catppuccin-mocha.json tokyo-night missing; do
  export CHEAT_TEST_STYLE=$style
  for sheet in tmux index; do
    export CHEAT_TEST_SHEET=$sheet
    "$root/.local/bin/cheat"
    expected_style=$style
    [[ $style == *.json ]] && expected_style="$XDG_CONFIG_HOME/glow/$style"
    [[ $style == missing ]] && expected_style=dark
    expected_file="$CHEAT_SHEETS_DIR/$sheet.md"
    [[ $sheet == index ]] && expected_file="$CHEAT_SHEETS_DIR/README.md"
    expected=$(printf '%s\n' --style "$expected_style" -w 72 "$expected_file")
    [[ $(<"$CHEAT_TEST_ARGS") == $expected ]] || fail "Incorrect preview arguments: $style / $sheet"
  done
done

print 'PASS: cheat preview styles, width, index mapping, and paths with spaces'

cat > "$temporary/bin/tput" <<'EOF'
#!/bin/bash
printf '80\n'
EOF
chmod +x "$temporary/bin/tput"

for command in opencode oc opencode.exe; do
  SSH_CONNECTION=fixture "$root/.local/bin/cheat" --for-command "$command"
  expected=$(printf '%s\n' -w 80 -p "$CHEAT_SHEETS_DIR/opencode.md")
  [[ $(<"$CHEAT_TEST_ARGS") == $expected ]] || fail "Incorrect sheet for command: $command"
done

sheets=$("$root/.local/bin/cheat" --list)
[[ $'\n'$sheets$'\n' == *$'\nopencode\n'* ]] || fail 'OpenCode missing from picker list'
print 'PASS: OpenCode command lookup, alias, and picker listing'

cat > "$temporary/bin/open" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$CHEAT_TEST_ARGS"
EOF
chmod +x "$temporary/bin/open"

SSH_CONNECTION= "$root/.local/bin/cheat" --tmux --for-command opencode.exe
expected=https://github.com/pedropombeiro/dotfiles/blob/master/.github/cheatsheets/opencode.md
[[ $(<"$CHEAT_TEST_ARGS") == $expected ]] || fail 'Incorrect tmux OpenCode browser lookup'
print 'PASS: tmux OpenCode process name opens its sheet without the picker'
