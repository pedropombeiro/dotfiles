#!/usr/bin/env zsh
emulate -LR zsh
setopt err_exit pipe_fail
scripts=${0:A:h:h}
repo=${scripts:h:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox python3
trap test_cleanup EXIT

python3 - "$repo" <<'PY'
import json, os, plistlib, re, runpy, sys
from pathlib import Path
from unittest.mock import patch
repo = Path(sys.argv[1])
module = runpy.run_path(str(repo / '.local/bin/dotfiles-theme'))
render = module['render_iterm2']
config = Path(os.environ['XDG_CONFIG_HOME'])
render.__globals__.update(CONFIG=config, ROOT=config / 'dotfiles')
directory = config / 'iterm2'
(directory / 'themes').mkdir(parents=True)
(directory / 'config').mkdir()
mapping = json.loads((repo / '.config/iterm2/dynamic-profiles.json').read_text())
expected_names = {
    'Default', 'GDK', 'GDK rails console',
    'GDK development logs', 'GDK Postgres console',
    'Clickhouse client',
    'Postgres thin clone (CI)', 'Postgres thin clone (main)',
}
assert {p['name'] for p in mapping['profiles']} == expected_names
setup = (repo / '.config/yadm/scripts/iterm2-setup.sh##class.Work,os.Darwin').read_text()
used_names = set(re.findall(r'(?:ensureTab\(targetWindow, |with profile )"([^"\n]+)"', setup))
assert used_names == expected_names - {
    'Postgres thin clone (CI)', 'Postgres thin clone (main)',
}
assert '"$HOME/.local/bin/dotfiles-theme" apply' in setup.split('osascript')[0]
assert 'split horizontally with profile "GDK development logs"' in setup
(directory / 'dynamic-profiles.json').write_text(json.dumps(mapping))
preferences = directory / 'config/com.googlecode.iterm2.plist'
parents = [{'Guid': item['parent_guid'], 'Name': item['name'] + ' · base', 'Command': 'preserved'}
           for item in mapping['profiles']]
original = plistlib.dumps({'New Bookmarks': parents})
preferences.write_bytes(original)
color = {'Red Component': .1, 'Green Component': .2, 'Blue Component': .3}
palette = {key: color for key in ['Background Color', 'Foreground Color', 'Cursor Color',
           'Cursor Text Color', 'Selection Color', 'Selected Text Color',
           *(f'Ansi {i} Color' for i in range(16))]}
palette['Command'] = 'must not import'
target = Path.home() / 'Library/Application Support/iTerm2/DynamicProfiles/dotfiles-theme.json'
with patch.object(sys, 'platform', 'linux'):
    assert render('missing') == {}
with patch.object(sys, 'platform', 'darwin'):
    identities = None
    for theme in ('gruvbox-dark', 'tokyonight-night', 'catppuccin-mocha'):
        (directory / f'themes/{theme}.itermcolors').write_bytes(plistlib.dumps(palette))
        outputs = render(theme)
        profiles = json.loads(outputs[target])['Profiles']
        assert len(profiles) == len(expected_names)
        assert all('Command' not in p and 'Normal Font' not in p for p in profiles)
        assert all(p['Background Color'] == color for p in profiles)
        assert all(p['Use Separate Colors for Light and Dark Mode'] is False for p in profiles)
        current = [p['Guid'] for p in profiles]
        assert identities is None or current == identities
        identities = current
        assert render(theme) == outputs
    assert preferences.read_bytes() == original
    # iTerm2 saves loaded generated children in New Bookmarks on some versions.
    cached = [{**p, 'Dynamic Profile Filename': str(target)} for p in profiles]
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents + cached}))
    assert render('catppuccin-mocha') == outputs
    cached[0]['Dynamic Profile Filename'] = str(target.with_name('unrelated.json'))
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents + cached}))
    try:
        render('catppuccin-mocha')
    except ValueError:
        pass
    else:
        raise AssertionError('another dynamic file can claim managed GUIDs')
    preferences.write_bytes(original)
    saved_palette = (directory / 'themes/gruvbox-dark.itermcolors').read_bytes()
    (directory / 'themes/gruvbox-dark.itermcolors').write_bytes(plistlib.dumps({}))
    try:
        render('gruvbox-dark')
    except ValueError:
        pass
    else:
        raise AssertionError('incomplete palette accepted')
    (directory / 'themes/gruvbox-dark.itermcolors').write_bytes(saved_palette)
    # Apple's plist reader accepts key-binding control characters rejected by XML.
    preferences.write_bytes(b'<?xml version="1.0"?><plist><dict><key>bad\x01</key></dict></plist>')
    with patch.object(module['subprocess'], 'run') as run:
        run.return_value.stdout = json.dumps({'New Bookmarks': parents})
        assert len(json.loads(render('gruvbox-dark')[target])['Profiles']) == len(expected_names)
        assert run.call_args.args[0] == ['plutil', '-convert', 'json', '-o', '-', str(preferences)]
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents[:1]}))
    assert len(json.loads(render('gruvbox-dark')[target])['Profiles']) == 1
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': []}))
    try:
        render('gruvbox-dark')
    except ValueError:
        pass
    else:
        raise AssertionError('missing required parent accepted')
    preferences.write_bytes(original)
    mapping['profiles'][0]['guid'] = parents[0]['Guid']
    (directory / 'dynamic-profiles.json').write_text(json.dumps(mapping))
    try:
        render('gruvbox-dark')
    except ValueError:
        pass
    else:
        raise AssertionError('colliding GUID accepted')
    preferences.unlink()
    assert render('missing') == {}
    root = config / 'dotfiles'
    (root / 'themes/gruvbox').mkdir(parents=True)
    (root / 'themes/gruvbox/assets.json').write_text(json.dumps({'sources': [{
        'repository': 'fixture/theme', 'revision': 'a' * 40,
        'files': {'iterm2/themes/missing.itermcolors': 'missing'}
    }]}))
    try:
        module['validate_assets']('gruvbox')
    except ValueError as error:
        assert 'dotfiles-theme install gruvbox' in str(error)
    else:
        raise AssertionError('missing runtime palette accepted')
PY
print 'PASS: iTerm2 Dynamic Profiles, stable identities, inheritance, and platform guards'
