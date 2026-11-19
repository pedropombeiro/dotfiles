#!/usr/bin/env zsh

# Use a private server and the real mode-indicator initializer when installed.
emulate -LR zsh
setopt err_exit pipe_fail
repo=${0:A:h:h:h:h:h}
if ! (( $+commands[tmux] )); then
  [[ ${REQUIRE_TMUX_THEME_TESTS:-0} != 1 ]] || exit 1
  print 'SKIP: tmux theme integration requires tmux'
  exit 0
fi
indicator=$HOME/.local/share/tmux/plugins/tmux-mode-indicator/mode_indicator.tmux
if [[ ! -x $indicator ]]; then
  [[ ${REQUIRE_TMUX_THEME_TESTS:-0} != 1 ]] || exit 1
  print 'SKIP: tmux theme integration requires the installed tmux-mode-indicator plugin'
  exit 0
fi
source "$repo/.config/yadm/scripts/tests/lib/test-helpers.zsh"
test_sandbox tmux cp mkdir python3
socket=
trap '[[ -n $socket ]] && tmux -S "$socket" kill-server 2>/dev/null || true; test_cleanup' EXIT

load_theme() {
  local theme=$1
  python3 - "$repo" "$theme" "$TEST_SANDBOX/theme.conf" <<'PY'
from pathlib import Path
import sys, runpy
repo, theme, target = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
template = (repo / ".config/tmux/theme.conf.theme").read_text()
module = runpy.run_path(str(repo / ".local/bin/dotfiles-theme"))
render = module["render_tmux"]
render.__globals__.update(CONFIG=repo / ".config", ROOT=repo / ".config/dotfiles")
values = {"tmux": theme}
render(values)
palette = values["tmux_config"]
assert "@plugin" not in palette, "theme plugin would change initialization order"
target.write_text(template.replace("@THEME_tmux_config@", palette))
target.with_name("status.conf").write_text(values["tmux_status"])
PY
  tmux source-file "$TEST_SANDBOX/theme.conf"
  tmux source-file "$TEST_SANDBOX/status.conf"
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
  elif [[ $theme == catppuccin-mocha ]]; then
    [[ $active == *'#[bg=#181825,fg=#fab387]●'* ]] || test_fail 'Catppuccin waiting bullet has no dark contrast patch'
  fi
  tmux set-option -wu @opencode-waiting
}

snapshot() {
  tmux show-options -g
  tmux show-options -gw
}

for theme in gruvbox tokyonight-night catppuccin-mocha; do
  # Use a fresh socket per server: tmux 3.6a's systemd pane child can still hold
  # the previous server's listening socket briefly after kill-server.
  socket=$TEST_SANDBOX/tmux-$theme.sock
  unset TMUX
  tmux -S "$socket" -f /dev/null new-session -d -s theme-test
  export TMUX="$socket,0,0"
  load_theme "$theme"
  snapshot > "$TEST_SANDBOX/before"
  for other in gruvbox tokyonight-night catppuccin-mocha; do
    [[ $other != $theme ]] || continue
    load_theme "$other"
    load_theme "$theme"
    snapshot > "$TEST_SANDBOX/after"
    diff -u "$TEST_SANDBOX/before" "$TEST_SANDBOX/after" || test_fail "$theme depends on $other"
  done
  tmux source-file "$repo/.config/tmux/tmux.platform.conf##distro.qts"
  [[ $(tmux show-options -gqv status-left) == *'bg=colour124'*'#S'* ]] || test_fail 'NAS session identity lost'
  tmux kill-server
  socket=
done
print 'PASS: fresh tmux themes, both switch directions, mode expansion, layout, and waiting indicators'
