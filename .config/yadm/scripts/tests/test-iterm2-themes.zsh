#!/usr/bin/env zsh
emulate -LR zsh
setopt err_exit pipe_fail
scripts=${0:A:h:h}
repo=${scripts:h:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox python3
trap test_cleanup EXIT

python3 - "$repo" <<'PY'
import contextlib, io, json, os, plistlib, re, runpy, sys
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
# Both machine classes must keep base names distinct from generated children.
# Ignore XML-invalid key-binding controls in memory: this check only needs names
# and GUIDs, and must run on Linux without Apple's plutil. Never alter the source.
for source in (repo / '.config/iterm2/config').glob('com.googlecode.iterm2.plist##*'):
    data = re.sub(rb'[\x00-\x08\x0b\x0c\x0e-\x1f]', b'', source.read_bytes())
    bookmarks = plistlib.loads(data)['New Bookmarks']
    bases = {p['Guid']: p for p in bookmarks if not p.get('Dynamic Profile Filename')}
    for item in mapping['profiles']:
        if item['parent_guid'] in bases:
            assert item['name'] not in {p['Name'] for p in bases.values()}, source.name
expected_names = {
    'Default', 'GDK', 'GDK rails console',
    'GDK development logs', 'GDK Postgres console',
    'Clickhouse client',
    'Postgres thin clone (CI)', 'Postgres thin clone (main)',
    'nas', 'unifi',
}
assert {p['name'] for p in mapping['profiles']} == expected_names
setup = (repo / '.config/yadm/scripts/iterm2-setup.sh##class.Work,os.Darwin').read_text()
used_names = set(re.findall(r'(?:ensureTab\(targetWindow, |with profile )"([^"\n]+)"', setup))
assert used_names == expected_names - {
    'Postgres thin clone (CI)', 'Postgres thin clone (main)',
    'nas', 'unifi',
}
assert '"$HOME/.local/bin/dotfiles-theme" iterm-apply' in setup.split('osascript')[0]
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
    # Personal connection profiles inherit commands and settings, changing colors only.
    personal_source = next((repo / '.config/iterm2/config').glob('*##*class.Personal*'))
    personal = module['read_iterm2_plist'](personal_source)
    preferences.write_bytes(personal_source.read_bytes())
    personal_original = preferences.read_bytes()
    personal_parents = {p['Guid']: p for p in personal['New Bookmarks']}
    for theme in ('gruvbox-dark', 'tokyonight-night', 'catppuccin-mocha'):
        (directory / f'themes/{theme}.itermcolors').write_bytes(plistlib.dumps(palette))
        children = json.loads(render(theme)[target])['Profiles']
        assert {p['Name'] for p in children} == {'Default', 'nas', 'unifi'}
        for child in children:
            parent = personal_parents[child['Dynamic Profile Parent GUID']]
            assert parent['Name'] == child['Name'] + ' · base'
            assert 'Command' not in child and 'Initial Text' not in child
            assert child['Background Color'] == color
        assert preferences.read_bytes() == personal_original
    preferences.write_bytes(original)
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
    # Discovery is explicit, local, and stores aliases only. No connection commands.
    inventory = directory / 'thin-clones.local.json'
    refresh = module['refresh_thin_clones']
    records = [dict(alias=alias, id='private.invalid', port=9999,
                    dbname='private_database', access_token='fixture-secret')
               for alias in ('main', 'ci', 'review')]
    with patch.object(module['subprocess'], 'run') as run:
        run.return_value.returncode = 0
        run.return_value.stdout = json.dumps(records)
        refresh(dry_run=True)
        assert not inventory.exists()
        refresh()
        assert run.call_args.args[0] == ['mise', 'x', 'ruby', '--', 'pgai', 'env', 'list']
        assert run.call_args.kwargs['timeout'] == 120
    assert json.loads(inventory.read_text()) == {'version': 1, 'aliases': ['ci', 'main', 'review']}
    assert inventory.stat().st_mode & 0o777 == 0o600
    before = inventory.read_bytes()
    with patch.object(module['subprocess'], 'run') as run:
        run.return_value.returncode = 0
        run.return_value.stdout = json.dumps(records)
        inventory.chmod(0o644)
        refresh()
        assert inventory.stat().st_mode & 0o777 == 0o600
        for bad in ('not json', '{}', '[{}]', '[{"alias":"--help"}]',
                    '[{"alias":"a;echo bad"}]', '[{"alias":"a"},{"alias":"a"}]'):
            run.return_value.stdout = bad
            try:
                refresh()
            except ValueError:
                pass
            else:
                raise AssertionError('invalid inventory accepted')
            assert inventory.read_bytes() == before
        run.return_value.returncode = 1
        try:
            refresh()
        except ValueError:
            pass
        else:
            raise AssertionError('failed discovery accepted')
        assert inventory.read_bytes() == before
        run.return_value.returncode = 0
        run.return_value.stdout = '[{"alias":"ci"},{"alias":"main"}]'
        try:
            refresh()
        except ValueError:
            pass
        else:
            raise AssertionError('unreviewed removal accepted')
        assert inventory.read_bytes() == before
        refresh(dry_run=True)
        assert inventory.read_bytes() == before
    for failure in (OSError('fixture'), module['subprocess'].TimeoutExpired('fixture', 120)):
        with patch.object(module['subprocess'], 'run', side_effect=failure):
            try:
                refresh()
            except ValueError:
                pass
            else:
                raise AssertionError('unavailable discovery accepted')
        assert inventory.read_bytes() == before
    with patch.object(module['subprocess'], 'run', side_effect=AssertionError('implicit discovery')):
        generated = json.loads(render('gruvbox-dark')[target])['Profiles']
    by_name = {p['Name']: p for p in generated}
    assert len(generated) == len(expected_names) + 1
    common = mapping['thin_clones']['parent_guid']
    for alias, identity in mapping['thin_clones']['legacy'].items():
        child = by_name[identity['name']]
        assert child['Guid'] == identity['guid']
        assert child['Dynamic Profile Parent GUID'] == common
        assert child['Custom Command'] == 'No'
        assert child['Initial Text'].endswith(f'pgai connect {alias}; mise x ruby -- pgai destroy {alias}')
        assert child['Shortcut'] == identity.get('shortcut', '')
        assert 'Working Directory' not in child and 'Normal Font' not in child
    assert by_name['Postgres thin clone (review)']['Shortcut'] == ''
    with contextlib.redirect_stdout(io.StringIO()) as preview:
        module['preview_iterm2']('gruvbox-dark')
    summaries = json.loads(preview.getvalue())
    assert len(summaries) == len(generated)
    assert all(not p.get('Changed inherited preference keys') for p in summaries)
    changed_parents = [dict(p) for p in parents]
    next(p for p in changed_parents
         if p['Guid'] == mapping['profiles'][6]['parent_guid'])['Normal Font'] = 'fixture-only-font'
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': changed_parents}))
    with contextlib.redirect_stdout(io.StringIO()) as preview:
        module['preview_iterm2']('gruvbox-dark')
    assert 'fixture-only-font' not in preview.getvalue()
    ci_summary = next(p for p in json.loads(preview.getvalue()) if p['Name'] == 'Postgres thin clone (CI)')
    assert ci_summary['Changed inherited preference keys'] == ['Normal Font']
    preferences.write_bytes(original)
    assert render('gruvbox-dark') == render('gruvbox-dark')
    cached = [{**p, 'Dynamic Profile Filename': str(target)} for p in generated]
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents + cached}))
    assert json.loads(render('gruvbox-dark')[target])['Profiles'] == generated
    preferences.write_bytes(original)
    inventory.write_text(json.dumps({'version': 1, 'aliases': ['review', 'main', 'ci']}))
    assert json.loads(render('gruvbox-dark')[target])['Profiles'] == generated
    # A GUID claimed by an unrelated profile must fail even for a new alias.
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents + [
        {'Guid': by_name['Postgres thin clone (review)']['Guid'], 'Name': 'unrelated'}]}))
    try:
        render('gruvbox-dark')
    except ValueError:
        pass
    else:
        raise AssertionError('new alias GUID collision accepted')
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents[:1]}))
    assert len(json.loads(render('gruvbox-dark')[target])['Profiles']) == 1
    preferences.write_bytes(original)
    with patch.object(module['subprocess'], 'run') as run:
        run.return_value.returncode = 0
        run.return_value.stdout = '[]'
        refresh(allow_removed=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    other = target.with_name('unrelated.json')
    inventory.write_bytes(before)
    for collision in (
        {'Guid': by_name['Postgres thin clone (review)']['Guid'], 'Name': 'unrelated'},
        {'Guid': 'unrelated', 'Name': 'Postgres thin clone (review)'},
    ):
        other.write_text(json.dumps({'Profiles': [collision]}))
        try:
            render('gruvbox-dark')
        except ValueError:
            pass
        else:
            raise AssertionError('unpersisted dynamic collision accepted')
    other.unlink()
    inventory.write_text(json.dumps({'version': 1, 'aliases': []}))
    assert len(json.loads(render('gruvbox-dark')[target])['Profiles']) == len(expected_names) - 2
    for invalid in ({'version': 2, 'aliases': []}, {'version': 1, 'aliases': ['a', 'a']},
                    {'version': 1, 'aliases': [], 'host': 'private.invalid'}):
        inventory.write_text(json.dumps(invalid))
        try:
            render('gruvbox-dark')
        except ValueError:
            pass
        else:
            raise AssertionError('invalid cache accepted')
    inventory.unlink()
    assert preferences.read_bytes() == original
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
    # The dedicated CLI renders only iTerm2, without discovery or other assets.
    with patch.object(sys, 'argv', ['dotfiles-theme', 'iterm-apply']), \
         patch.dict(module['main'].__globals__, {
             'load_theme': lambda *_: ('fixture', {'iterm': 'gruvbox-dark'}),
             'render': lambda *_: (_ for _ in ()).throw(AssertionError('rendered other apps')),
             'validate_assets': lambda *_: (_ for _ in ()).throw(AssertionError('validated other apps')),
         }), \
         patch.object(module['subprocess'], 'run', side_effect=AssertionError('implicit discovery')):
        module['main']()
        saved = target.read_bytes()
        assert target.stat().st_mode & 0o777 == 0o600
        module['main']()
        assert target.read_bytes() == saved
    assert preferences.read_bytes() == original
    cap_root = Path.home() / 'environments'
    cap_root.mkdir()
    for name in ('cap-123', 'cap-456', 'cap-invalid', 'legacy'):
        (cap_root / name).mkdir()
        (cap_root / name / 'caproni.yaml').write_text('version: 2\n')
    refresh_caproni = module['refresh_caproni']
    cap_cache = directory / 'caproni.local.json'
    with patch.object(module['subprocess'], 'run', side_effect=AssertionError('live Caproni command')):
        refresh_caproni(str(cap_root), [str(cap_root / 'legacy')], dry_run=True)
        assert not cap_cache.exists()
        refresh_caproni(str(cap_root), [str(cap_root / 'legacy')])
        cap_profiles = module['caproni_mappings'](mapping)
        assert len(cap_profiles) == 3
        assert cap_cache.stat().st_mode & 0o777 == 0o600
        assert all(p['overrides']['Command'] == '/bin/zsh -l' and p['overrides']['Initial Text'] == '' for p in cap_profiles)
        assert all(p['overrides']['Shortcut'] == '' for p in cap_profiles)
        assert all(p['overrides']['Icon'] == 2 for p in cap_profiles)
        assert all(p['overrides']['Custom Icon Path'] == str(directory / 'icons/caproni.ico') for p in cap_profiles)
        assert module['caproni_mappings'](mapping) == cap_profiles
        assert len(json.loads(render('gruvbox-dark')[target])['Profiles']) == len(expected_names) + 3
        saved_inventory = cap_cache.read_bytes()
        (cap_root / 'cap-123/caproni.yaml').unlink()
        try:
            refresh_caproni()
        except ValueError:
            pass
        else:
            raise AssertionError('unreviewed Caproni removal accepted')
        assert cap_cache.read_bytes() == saved_inventory
        refresh_caproni(allow_removed=True)
        assert len(module['caproni_mappings'](mapping)) == 2
    cap_cache.unlink()
    # Private role settings remain authoritative after the original bases are retired.
    shared_guid = mapping['profiles'][1]['parent_guid']
    role_settings = {
        p['guid']: {'parent_guid': shared_guid, 'overrides': {
            'Command': 'fixture command', 'Initial Text': '', 'Triggers': [],
            'Title Components': 2, 'Open Password Manager Automatically': False,
        }} for p in mapping['profiles'][1:6]
    }
    role_settings[mapping['profiles'][2]['guid']]['overrides'].update({
        'Option Key Sends': 2, 'Title Components': 32,
    })
    snapshot_path = directory / 'gdk.local.json'
    snapshot_path.write_text(json.dumps({'version': 1, 'profiles': role_settings}))
    snapshot = snapshot_path.read_bytes()
    preferences.write_bytes(plistlib.dumps({'New Bookmarks': parents[:2] + parents[6:]}))
    migrated = json.loads(render('gruvbox-dark')[target])['Profiles']
    rails = next(p for p in migrated if p['Name'] == 'GDK rails console')
    assert rails['Option Key Sends'] == 2
    assert rails['Guid'] == mapping['profiles'][2]['guid']
    assert rails['Dynamic Profile Parent GUID'] == mapping['profiles'][1]['parent_guid']
    assert rails['Triggers'] == []
    assert rails['Title Components'] == 32
    assert len(migrated) == len(expected_names)
    assert all(p['Dynamic Profile Parent GUID'] == shared_guid
               for p in migrated if p['Name'].startswith('GDK') or p['Name'] == 'Clickhouse client')
    logs = next(p for p in migrated if p['Name'] == 'GDK development logs')
    assert logs['Title Components'] == 2 and logs['Triggers'] == []
    with patch.object(sys, 'argv', ['dotfiles-theme', 'iterm-apply']), \
         patch.dict(module['main'].__globals__, {'load_theme': lambda *_: ('fixture', {'iterm': 'gruvbox-dark'})}):
        module['main']()
    assert snapshot_path.read_bytes() == snapshot
    assert json.loads(target.read_text())['Profiles'] == migrated
    for invalid in ({'version': 2, 'profiles': role_settings},
                    {'version': 1, 'profiles': {'unrelated': role_settings[mapping['profiles'][1]['guid']]}},
                    {'version': 1, 'profiles': {mapping['profiles'][1]['guid']: {
                        'parent_guid': shared_guid, 'overrides': {'Guid': 'changed'}}}}):
        snapshot_path.write_text(json.dumps(invalid))
        try:
            render('gruvbox-dark')
        except ValueError:
            pass
        else:
            raise AssertionError('invalid private role settings accepted')
    snapshot_path.unlink()
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
