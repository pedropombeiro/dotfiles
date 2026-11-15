#!/usr/bin/env zsh

# Use a private server and the real mode-indicator initializer when installed.
emulate -LR zsh
setopt err_exit pipe_fail
repo=${0:A:h:h:h:h:h}
if ! (( $+commands[tmux] )); then
  print 'SKIP: tmux theme integration requires tmux'
  exit 0
fi
indicator=$HOME/.local/share/tmux/plugins/tmux-mode-indicator/mode_indicator.tmux
if [[ ! -x $indicator ]]; then
  print 'SKIP: tmux theme integration requires the installed tmux-mode-indicator plugin'
  exit 0
fi
source "$repo/.config/yadm/scripts/tests/lib/test-helpers.zsh"
test_sandbox tmux cp mkdir python3
socket=$TEST_SANDBOX/tmux.sock
trap 'tmux -S "$socket" kill-server 2>/dev/null || true; test_cleanup' EXIT
unset TMUX
tmux -S "$socket" -f /dev/null new-session -d -s theme-test
export TMUX="$socket,0,0"

load_theme() {
  local theme=$1
  python3 - "$repo" "$theme" "$TEST_SANDBOX/theme.conf" <<'PY'
from pathlib import Path
import sys
repo, theme, target = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
template = (repo / ".config/tmux/theme.conf.theme").read_text()
palette = (repo / f".config/tmux/themes/{theme}.conf").read_text()
assert "@plugin" not in palette, "theme plugin would change initialization order"
target.write_text(template.replace("@THEME_tmux_config@", palette))
PY
  tmux source-file "$TEST_SANDBOX/theme.conf"
  tmux source-file "$repo/.config/tmux/themes/$theme-status.conf"
  # Production TPM expands this after the native theme has been sourced.
  "$indicator"
  local right=$(tmux show-options -gqv status-right)
  [[ $right != *'#{tmux_mode_indicator}'* ]] || test_fail 'mode indicator was not expanded'
  [[ $right == *'WAIT'*'COPY'*'SYNC'*'TMUX'* ]] || test_fail 'mode states missing'
  [[ $right == *''*''*''* ]] || test_fail 'right status separators missing'
  test_assert_equal 'session-name allowance' 80 "$(tmux show-options -gqv status-left-length)"
  test_assert_equal 'window separator' '' "$(tmux show-options -gwqv window-status-separator)"
  tmux set-option -w @opencode-waiting 1
  local active=$(tmux display-message -p '#{E:window-status-current-format}')
  [[ $active == *'●'* ]] || test_fail 'waiting indicator missing'
  if [[ $theme == tokyonight-night ]]; then
    [[ $active == *'#[bg=#16161e,fg=#ff9e64]●'* ]] || test_fail 'waiting bullet has no dark contrast patch'
  fi
  tmux set-option -wu @opencode-waiting
}

snapshot() {
  tmux show-options -g
  tmux show-options -gw
}

for theme in gruvbox tokyonight-night; do
  # Establish a fresh baseline, then switch away and back on the same server.
  tmux kill-server
  tmux -S "$socket" -f /dev/null new-session -d -s theme-test
  load_theme "$theme"
  snapshot > "$TEST_SANDBOX/before"
  if [[ $theme == gruvbox ]]; then
    load_theme tokyonight-night
  else
    load_theme gruvbox
  fi
  load_theme "$theme"
  snapshot > "$TEST_SANDBOX/after"
  diff -u "$TEST_SANDBOX/before" "$TEST_SANDBOX/after" || test_fail "$theme depends on previous theme"
  tmux source-file "$repo/.config/tmux/tmux.platform.conf##distro.qts"
  [[ $(tmux show-options -gqv status-left) == *'bg=colour124'*'#S'* ]] || test_fail 'NAS session identity lost'
done
print 'PASS: fresh tmux themes, both switch directions, mode expansion, layout, and waiting indicators'
