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
for template in palette.conf.theme status.conf.theme; do
  cp "$repo/.config/tmux/$template" "$XDG_CONFIG_HOME/tmux/"
done

# Mark offline fixture assets with the same revision and content metadata as install.
stamp_assets() {
  python3 - "$XDG_CONFIG_HOME" "$1" <<'PY'
import hashlib, json, sys
from pathlib import Path
root, name = Path(sys.argv[1]), sys.argv[2]
manifest = json.loads((root / f"dotfiles/themes/{name}/assets.json").read_text())
state = {}
for source in manifest["sources"]:
    for target in source["files"]:
        path = root / target
        if path.exists():
            state[target] = {
                "source": {key: source[key] for key in ("repository", "revision")},
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
directory = root / "dotfiles/assets"
directory.mkdir(exist_ok=True)
(directory / f"{name}.json").write_text(json.dumps(state))
PY
}
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
print 'update_ms = 9876' >> "$XDG_CONFIG_HOME/btop/btop.conf.theme"
test_expect_status 'updated btop defaults' 0 python3 "$command_path" apply
[[ $(<"$XDG_CONFIG_HOME/btop/btop.conf") == *'update_ms = 9876'* ]] || test_fail 'btop ignores updated defaults'
[[ $(<"$XDG_CONFIG_HOME/btop/local.json") == *'interactive_fixture'* ]] || test_fail 'btop local preferences not captured'
print 'update_ms = 4321' >> "$XDG_CONFIG_HOME/btop/btop.conf"
test_expect_status 'capture btop interactive preference' 0 python3 "$command_path" apply
python3 - "$XDG_CONFIG_HOME/btop/local.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
preferences = json.loads(path.read_text())
assert preferences.pop("update_ms") == "4321"
path.write_text(json.dumps(preferences))
PY
test_expect_status 'reset btop local preference' 0 python3 "$command_path" apply
[[ $(<"$XDG_CONFIG_HOME/btop/btop.conf") == *'update_ms = 9876'* ]] || test_fail 'btop local preference cannot be reset'
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
stamp_assets tokyonight-night
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
test_assert_equal 'Tokyo Night prompt gap uses terminal background' '' "$POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_BACKGROUND"
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

# Validate the third profile without network access, then clear its overrides.
cp "$repo/.config/dotfiles/themes/catppuccin-mocha.json" "$XDG_CONFIG_HOME/dotfiles/themes/"
cp -R "$repo/.config/dotfiles/themes/catppuccin-mocha" "$XDG_CONFIG_HOME/dotfiles/themes/"
test_expect_status 'missing Catppuccin assets' 1 python3 "$command_path" set catppuccin-mocha
test_assert_equal 'missing Catppuccin assets preserve selection' gruvbox "$(python3 "$command_path" get)"
python3 - "$XDG_CONFIG_HOME" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
manifest = json.loads((root / "dotfiles/themes/catppuccin-mocha/assets.json").read_text())
for source in manifest["sources"]:
    assert len(source["revision"]) == 40
    for target in source["files"]:
        if target.startswith("iterm2/"):
            continue
        path = root / target
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('[mgr]\n' if target.endswith('.toml') else 'fixture asset\n')
PY
stamp_assets catppuccin-mocha
test_expect_status 'real Catppuccin profile' 0 python3 "$command_path" set catppuccin-mocha
theme-refresh
test_assert_equal 'Catppuccin directory accent' '#89b4fa' "$POWERLEVEL9K_DIR_BACKGROUND"
test_assert_equal 'Catppuccin user accent' '#89dceb' "$POWERLEVEL9K_USER_DEFAULT_BACKGROUND"
test_assert_equal 'Catppuccin prompt gap uses terminal background' '' "$POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_BACKGROUND"
[[ $FZF_DEFAULT_OPTS == *'bg:#1e1e2e'* ]] || test_fail 'Catppuccin fzf colors'
[[ $(<"$XDG_CONFIG_HOME/bat/config") == *'--theme="Catppuccin Mocha"'* ]] || test_fail 'Catppuccin bat theme'
[[ $(<"$XDG_CONFIG_HOME/lnav/config.json") == *'"catppuccin-mocha": {'* ]] || test_fail 'Catppuccin lnav theme'
[[ $(<"$XDG_CONFIG_HOME/glow/glow.yml") == *'/glow/catppuccin-mocha.json"'* ]] || test_fail 'Catppuccin Glow style'
python3 - "$XDG_CONFIG_HOME" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
preferences = json.loads((root / 'opencode/cli.json').read_text())
assert preferences['theme']['name'] == 'catppuccin'
assert preferences['session'] == {'sidebar': 'hide'}
PY
test_expect_status 'switch from Catppuccin to Tokyo Night' 0 python3 "$command_path" set tokyonight-night
theme-refresh
test_assert_equal 'restore Tokyo Night after Catppuccin' '#7aa2f7' "$POWERLEVEL9K_DIR_BACKGROUND"
test_expect_status 'switch from Catppuccin cycle to Gruvbox' 0 python3 "$command_path" set gruvbox
theme-refresh
[[ ! -v POWERLEVEL9K_DIR_BACKGROUND ]] || test_fail 'Catppuccin overrides survive Gruvbox'
print 'PASS: Catppuccin asset guard, blue accents, mappings, and three-theme switching'

print 'changed asset' >> "$XDG_CONFIG_HOME/yazi/themes/catppuccin-mocha.toml"
test_expect_status 'reject modified assets' 1 python3 "$command_path" set catppuccin-mocha
stamp_assets catppuccin-mocha
python3 - "$XDG_CONFIG_HOME/dotfiles/themes/catppuccin-mocha/assets.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
manifest = json.loads(path.read_text())
manifest["sources"][0]["revision"] = "a" * 40
path.write_text(json.dumps(manifest))
PY
test_expect_status 'reject outdated asset revisions' 1 python3 "$command_path" set catppuccin-mocha
test_assert_equal 'stale assets preserve selection' gruvbox "$(python3 "$command_path" get)"

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

# Exercise installer and receipts offline, including interrupted downloads.
python3 - "$command_path" "$XDG_CONFIG_HOME" <<'PY'
import io, json, runpy, sys
from pathlib import Path
module = runpy.run_path(sys.argv[1])
install = module["install_assets"]
validate = module["validate_assets"]
root = Path(sys.argv[2])
install.__globals__.update(CONFIG=root, ROOT=root / "dotfiles")
install.__globals__["urlopen"] = lambda *args, **kwargs: io.BytesIO(b"installed fixture\n")
install.__globals__["shutil"].which = lambda name: None
install("catppuccin-mocha")
validate("catppuccin-mocha")
state = root / "dotfiles/assets/catppuccin-mocha.json"
before = state.read_bytes()
asset = root / "bat/themes/Catppuccin Mocha.tmTheme"
original = asset.read_bytes()
calls = 0
def interrupted(*args, **kwargs):
    global calls
    calls += 1
    if calls == 2:
        raise OSError("fixture network failure")
    return io.BytesIO(b"replacement")
install.__globals__["urlopen"] = interrupted
try:
    install("catppuccin-mocha")
except OSError:
    pass
else:
    raise AssertionError("installer ignored download failure")
assert state.read_bytes() == before
assert asset.read_bytes() == original
PY
print 'PASS: asset installation receipts and interrupted-download safety'

test_stub dotfiles-theme <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$THEME_TEST_LOG"
SH
cp "$TEST_SANDBOX/bin/dotfiles-theme" "$HOME/.local/bin/dotfiles-theme"
: > "$THEME_TEST_LOG"
test_expect_status 'bootstrap installs before rendering' 0 bash "$repo/.config/yadm/bootstrap.d/125-setup-theme.sh"
test_assert_equal 'bootstrap theme sequence' $'install\napply' "$(<"$THEME_TEST_LOG")"
