#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit pipe_fail
scripts=${0:A:h:h}
repo=${scripts:h:h:h}
command_path=$repo/.local/bin/dotfiles-theme
picker_path=$repo/.local/bin/dotfiles-fzf
refresh_path=$repo/.shellrc/zshrc.d/functions/theme-refresh
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox python3 cp mkdir cmp bash uname
trap test_cleanup EXIT

mkdir -p "$XDG_CONFIG_HOME/dotfiles/themes" "$XDG_CONFIG_HOME/glow"
print gruvbox > "$XDG_CONFIG_HOME/dotfiles/theme"
cp "$repo/.config/dotfiles/themes/gruvbox.json" "$XDG_CONFIG_HOME/dotfiles/themes/"
cp -R "$repo/.config/dotfiles/themes/gruvbox" "$XDG_CONFIG_HOME/dotfiles/themes/"
mkdir -p "$XDG_CONFIG_HOME/tmux"
cp -R "$repo/.config/tmux/themes" "$XDG_CONFIG_HOME/tmux/"
for theme in gruvbox tokyonight-night; do
  while IFS= read -r format; do
    [[ $format == 'set -gw window-status-format '* || $format == 'set -gw window-status-current-format '* ]] || continue
    [[ $format == *''*''* ]] || test_fail "$theme lost Powerline tab arrowheads"
  done < "$repo/.config/tmux/themes/$theme-status.conf"
done
right_status=$(<"$repo/.config/tmux/themes/tokyonight-night.conf")
[[ $right_status == *''*''*''*'#{tmux_mode_indicator}'* ]] || test_fail 'Tokyo Night lost right status separators'
[[ $right_status == *'%Y-%m-%d'*'%H:%M'* ]] || test_fail 'Tokyo Night lost date/time segments'
cp "$repo/.config/glow/gruvbox.json" "$XDG_CONFIG_HOME/glow/"
for target in bat/config atuin/config.toml btop/btop.conf lazygit/config.yml lnav/config.json yazi/theme.toml git/theme.conf tmux/theme.conf tmux/theme-status.conf trippy/trippy.toml glow/glow.yml; do
  mkdir -p "$XDG_CONFIG_HOME/${target:h}"
  cp "$repo/.config/$target.theme" "$XDG_CONFIG_HOME/$target.theme"
done

test_assert_equal 'default selection' gruvbox "$(python3 "$command_path" get)"
test_assert_equal 'application mapping' gruvbox-dark "$(python3 "$command_path" value bat)"
test_expect_status 'initial apply' 0 python3 "$command_path" apply
python3 - "$XDG_CONFIG_HOME/opencode/cli.json" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
preferences = json.loads(path.read_text())
assert preferences["theme"] == {"name": "gruvbox", "mode": "dark"}
assert preferences["$schema"] == "https://opencode.ai/v2/cli.json"
preferences.update(session={"sidebar": "hide"}, animations=False, plugins=["fixture"])
preferences["theme"]["fixture"] = "preserved"
path.write_text(json.dumps(preferences))
PY
[[ $(<"$XDG_CONFIG_HOME/glow/glow.yml") == *'/glow/gruvbox.json"'* ]] || test_fail 'Glow style'
[[ $(<"$XDG_CONFIG_HOME/bat/config") == *'--theme="gruvbox-dark"'* ]] || test_fail 'bat rendering'
[[ $(<"$XDG_CONFIG_HOME/yazi/theme.toml") == *'dark = "gruvbox-dark"'* ]] || test_fail 'Yazi flavor must be at the config root'
test_expect_status 'idempotent apply' 0 python3 "$command_path" apply
print 'interactive_fixture = true' >> "$XDG_CONFIG_HOME/btop/btop.conf"
test_expect_status 'preserve btop preferences' 0 python3 "$command_path" apply
[[ $(<"$XDG_CONFIG_HOME/btop/btop.conf") == *'interactive_fixture = true'* ]] || test_fail 'lost btop preferences'
test_expect_status 'reject unknown theme' 1 python3 "$command_path" set missing-theme
test_expect_status 'reject traversal' 1 python3 "$command_path" set ../gruvbox
test_assert_equal 'invalid set preserves selection' gruvbox "$(python3 "$command_path" get)"

# A synthetic profile proves consumers follow mappings rather than defaults.
python3 - "$XDG_CONFIG_HOME" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1]) / "dotfiles/themes"
profile = json.loads((root / "gruvbox.json").read_text())
profile.update(bat="fixture-bat", nvim="fixture-nvim", lualine="fixture-line", yazi="fixture-yazi")
(root / "fixture.json").write_text(json.dumps(profile))
PY
test_expect_status 'select synthetic profile' 0 python3 "$command_path" set fixture
test_assert_equal 'persist selection' fixture "$(python3 "$command_path" get)"
[[ $(<"$XDG_CONFIG_HOME/bat/config") == *'--theme="fixture-bat"'* ]] || test_fail 'bat ignores selection'
[[ $(<"$XDG_CONFIG_HOME/yazi/theme.toml") == *'dark = "fixture-yazi"'* ]] || test_fail 'Yazi ignores selection'
export NVIM_THEME=stale
source "$XDG_CONFIG_HOME/dotfiles/theme.sh"
test_assert_equal 'shell ignores stale exports' fixture-nvim "$NVIM_THEME"

export THEME_TEST_LOG="$TEST_SANDBOX/tmux-log"
test_stub tmux <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$THEME_TEST_LOG"
SH
test_expect_status 'explicit reload' 0 python3 "$command_path" apply --reload
test_assert_equal 'reload sequence' $'has-session\nsource-file '"$XDG_CONFIG_HOME/tmux/tmux.conf" "$(<"$THEME_TEST_LOG")"

cp "$XDG_CONFIG_HOME/bat/config" "$TEST_SANDBOX/before"
rm "$XDG_CONFIG_HOME/bat/config"
ln -s "$TEST_SANDBOX/before" "$XDG_CONFIG_HOME/bat/config"
test_expect_status 'reject output symlink' 1 python3 "$command_path" set gruvbox
test_assert_equal 'symlink rejection preserves choice' fixture "$(python3 "$command_path" get)"
rm "$XDG_CONFIG_HOME/bat/config"
cp "$TEST_SANDBOX/before" "$XDG_CONFIG_HOME/bat/config"

cp "$XDG_CONFIG_HOME/bat/config" "$TEST_SANDBOX/before"
print '@THEME_missing@' >> "$XDG_CONFIG_HOME/bat/config.theme"
test_expect_status 'validate before writing' 1 python3 "$command_path" set gruvbox
cmp "$XDG_CONFIG_HOME/bat/config" "$TEST_SANDBOX/before"
test_assert_equal 'failed render preserves selection' fixture "$(python3 "$command_path" get)"
print 'PASS: theme selection, mappings, rendering, shell exports, and failure safety'

# Render the real optional profile without downloads or changing the host theme.
cp "$repo/.config/bat/config.theme" "$XDG_CONFIG_HOME/bat/config.theme"
cp "$repo/.config/dotfiles/themes/tokyonight-night.json" "$XDG_CONFIG_HOME/dotfiles/themes/"
cp -R "$repo/.config/dotfiles/themes/tokyonight-night" "$XDG_CONFIG_HOME/dotfiles/themes/"
mkdir -p "$XDG_CONFIG_HOME/yazi/themes" "$XDG_CONFIG_HOME/bat/themes"
print '[mgr]' > "$XDG_CONFIG_HOME/yazi/themes/tokyonight-night.toml"
test_expect_status 'missing syntax asset' 1 python3 "$command_path" set tokyonight-night
print 'fixture syntax asset' > "$XDG_CONFIG_HOME/bat/themes/tokyonight_night.tmTheme"
test_expect_status 'real Tokyo Night profile' 0 python3 "$command_path" set tokyonight-night
python3 - "$XDG_CONFIG_HOME/opencode/cli.json" <<'PY'
import json
from pathlib import Path
import sys
preferences = json.loads(Path(sys.argv[1]).read_text())
assert preferences["theme"] == {"name": "tokyonight", "mode": "dark", "fixture": "preserved"}
assert preferences["session"] == {"sidebar": "hide"}
assert preferences["animations"] is False
assert preferences["plugins"] == ["fixture"]
PY
[[ $(<"$XDG_CONFIG_HOME/glow/glow.yml") == *'style: "tokyo-night"'* ]] || test_fail 'native Glow theme'
[[ $(<"$XDG_CONFIG_HOME/btop/btop.conf") == *'color_theme = "tokyo-night"'* ]] || test_fail 'native btop theme'
[[ $(<"$XDG_CONFIG_HOME/lnav/config.json") == *'"tokyonight-night": {'* ]] || test_fail 'lnav theme registration'
test_assert_equal 'real selection' tokyonight-night "$(python3 "$command_path" get)"
source "$XDG_CONFIG_HOME/dotfiles/prompt.zsh"
test_assert_equal 'Tokyo Night prompt background' '#7aa2f7' "$POWERLEVEL9K_DIR_BACKGROUND"
test_assert_equal 'Tokyo Night prompt foreground' '#16161e' "$POWERLEVEL9K_DIR_HOME_FOREGROUND"
test_assert_equal 'Tokyo Night forbidden directory background' '#f7768e' "$POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_BACKGROUND"
mkdir -p "$HOME/.shellrc/rc.d"
cp "$repo/.shellrc/rc.d/fzf.sh" "$HOME/.shellrc/rc.d/"
fpath=("${refresh_path:h}" $fpath)
autoload -Uz theme-refresh
typeset -g reload_count=0
p10k() { [[ $1 == reload ]] || test_fail 'unexpected p10k command'; (( ++reload_count )); }
export FZF_DEFAULT_OPTS='--color=bg:#282828'
theme-refresh
[[ $FZF_DEFAULT_OPTS == *'bg:#1a1b26'* ]] || test_fail 'refresh leaves stale fzf options'
test_assert_equal 'prompt reloaded once' 1 "$reload_count"
for picker in fzf fzf-tmux; do
  test_stub "$picker" <<'SH'
#!/bin/sh
printf '%s\n' "${0##*/}" "$@"
SH
done
export FZF_DEFAULT_COLOR='--color=bg:#282828'
export FZF_DEFAULT_OPTS='--color=bg:#282828'
picker_output=$(bash "$picker_path" --ansi)
[[ $picker_output == fzf$'\n--ansi\n--color='*'bg:#1a1b26'* ]] || test_fail 'shell picker uses stale theme'
picker_output=$(bash "$picker_path" --tmux -p 80%,70%)
[[ $picker_output == fzf-tmux$'\n-p\n80%,70%\n--color='*'bg:#1a1b26'* ]] || test_fail 'tmux picker uses stale theme'
test_expect_status 'switch back' 0 python3 "$command_path" set gruvbox
theme-refresh
[[ $FZF_DEFAULT_OPTS == *'bg:#32302f'* && $FZF_DEFAULT_OPTS != *'#1a1b26'* ]] || test_fail 'refresh does not restore Gruvbox fzf options'
test_assert_equal 'prompt reloaded twice' 2 "$reload_count"
python3 - "$XDG_CONFIG_HOME/opencode/cli.json" <<'PY'
import json
from pathlib import Path
import sys
preferences = json.loads(Path(sys.argv[1]).read_text())
assert preferences["theme"]["name"] == "gruvbox"
assert preferences["theme"]["mode"] == "dark"
assert preferences["session"] == {"sidebar": "hide"}
PY
source "$XDG_CONFIG_HOME/dotfiles/prompt.zsh"
[[ ! -v POWERLEVEL9K_DIR_BACKGROUND ]] || test_fail 'Tokyo Night background survives switch back'
[[ ! -v POWERLEVEL9K_HISTORY_BACKGROUND ]] || test_fail 'Tokyo Night history survives switch back'
test_assert_equal 'restore Gruvbox prompt foreground' gray93 "$POWERLEVEL9K_DIR_HOME_FOREGROUND"
print 'PASS: Tokyo Night profile, native theme mappings, asset guard, and switching back'

cp "$XDG_CONFIG_HOME/bat/config" "$TEST_SANDBOX/before"
print '{invalid' > "$XDG_CONFIG_HOME/opencode/cli.json"
test_expect_status 'reject invalid OpenCode preferences' 1 python3 "$command_path" set tokyonight-night
cmp "$XDG_CONFIG_HOME/bat/config" "$TEST_SANDBOX/before"
test_assert_equal 'invalid OpenCode config preserves selection' gruvbox "$(python3 "$command_path" get)"
test_assert_equal 'invalid OpenCode config remains untouched' '{invalid' "$(<"$XDG_CONFIG_HOME/opencode/cli.json")"
print 'PASS: OpenCode theme switching, preference preservation, and invalid-config safety'

# Appearance failures must not prevent the existing alternate-file maintenance.
mkdir -p "$HOME/.config/yadm/hooks" "$HOME/.config/yadm/scripts" "$HOME/.local/bin"
cp "$repo/.config/yadm/hooks/post_alt" "$HOME/.config/yadm/hooks/"
export HOOK_TEST_LOG="$TEST_SANDBOX/hook-log"
for helper in prune-dangling-alt-links relink-dotfiles update-gitignore-alt; do
  print 'print -r -- "${${(%):-%x}:t:r}" >> "$HOOK_TEST_LOG"' > "$HOME/.config/yadm/scripts/$helper.zsh"
done
print '#!/bin/sh\nexit 7' > "$HOME/.local/bin/dotfiles-theme"
chmod +x "$HOME/.local/bin/dotfiles-theme"
test_expect_status 'theme failure is nonfatal in post_alt' 0 zsh -df "$HOME/.config/yadm/hooks/post_alt"
test_assert_equal 'alternate maintenance still runs' $'prune-dangling-alt-links\nrelink-dotfiles\nupdate-gitignore-alt' "$(<"$HOOK_TEST_LOG")"
[[ $(<"$TEST_SANDBOX/output") == *'Warning: theme settings were not updated.'* ]] || test_fail 'theme failure is not reported'
print 'PASS: shell refresh and nonfatal post_alt theme failure'
