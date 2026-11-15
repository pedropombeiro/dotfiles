#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit pipe_fail
scripts=${0:A:h:h}
repo=${scripts:h:h:h}
command_path=$repo/.local/bin/dotfiles-theme
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox python3 cp mkdir cmp
trap test_cleanup EXIT

mkdir -p "$XDG_CONFIG_HOME/dotfiles/themes" "$XDG_CONFIG_HOME/glow"
cp "$repo/.config/dotfiles/theme" "$XDG_CONFIG_HOME/dotfiles/"
cp "$repo/.config/dotfiles/themes/gruvbox.json" "$XDG_CONFIG_HOME/dotfiles/themes/"
cp -R "$repo/.config/dotfiles/themes/gruvbox" "$XDG_CONFIG_HOME/dotfiles/themes/"
mkdir -p "$XDG_CONFIG_HOME/tmux"
cp -R "$repo/.config/tmux/themes" "$XDG_CONFIG_HOME/tmux/"
cp "$repo/.config/glow/gruvbox.json" "$XDG_CONFIG_HOME/glow/"
for target in bat/config atuin/config.toml btop/btop.conf lazygit/config.yml lnav/config.json yazi/theme.toml git/theme.conf tmux/theme.conf tmux/theme-status.conf trippy/trippy.toml glow/glow.yml; do
  mkdir -p "$XDG_CONFIG_HOME/${target:h}"
  cp "$repo/.config/$target.theme" "$XDG_CONFIG_HOME/$target.theme"
done

test_assert_equal 'default selection' gruvbox "$(python3 "$command_path" get)"
test_assert_equal 'application mapping' gruvbox-dark "$(python3 "$command_path" value bat)"
test_expect_status 'initial apply' 0 python3 "$command_path" apply
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
[[ $(<"$XDG_CONFIG_HOME/glow/glow.yml") == *'style: "tokyo-night"'* ]] || test_fail 'native Glow theme'
[[ $(<"$XDG_CONFIG_HOME/btop/btop.conf") == *'color_theme = "tokyo-night"'* ]] || test_fail 'native btop theme'
[[ $(<"$XDG_CONFIG_HOME/lnav/config.json") == *'"tokyonight-night": {'* ]] || test_fail 'lnav theme registration'
test_assert_equal 'real selection' tokyonight-night "$(python3 "$command_path" get)"
test_expect_status 'switch back' 0 python3 "$command_path" set gruvbox
print 'PASS: Tokyo Night profile, native theme mappings, asset guard, and switching back'
