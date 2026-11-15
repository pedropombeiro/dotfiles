#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit pipe_fail
scripts=${0:A:h:h}
repo=${scripts:h:h:h}
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox python3
trap test_cleanup EXIT

python3 - "$repo" <<'PY'
import hashlib
import json
import os
import runpy
import sys
from pathlib import Path
from types import SimpleNamespace

repo = Path(sys.argv[1])
root = Path(os.environ['XDG_CONFIG_HOME']) / 'dotfiles'
root.mkdir()
# Freeze the complete pre-refactor VisiData layout, including fixed graph colors.
expected = {
    'gruvbox': '084f2e13d8cc17874e28f8903ab41912217f23998b8af31c669ed0dc302d1dbb',
    'tokyonight-night': '3637a9d7d023f240a99cf3c6f1091ade6f88c9d76153c03850046e97e138358b',
    'catppuccin-mocha': 'ed1f702b9ef48a6e604df4b63822aa318120526830234e34551ed6fedfe5d4a0',
}
source = (repo / '.config/visidata/config.py').read_text()
section = source[source.index('theme_root ='):source.index('if options.theme')]
(root / 'themes').symlink_to(repo / '.config/dotfiles/themes', target_is_directory=True)
for name, digest in expected.items():
    profile = json.loads((root / f'themes/{name}.json').read_text())
    (root / 'theme.json').write_text(json.dumps({'name': name, **profile}))
    vd = SimpleNamespace(themes={})
    exec(section, dict(json=json, os=os, Path=Path, vd=vd))
    layout = vd.themes[profile['visidata']]
    assert hashlib.sha256(json.dumps(layout, sort_keys=True).encode()).hexdigest() == digest, name

module = runpy.run_path(str(repo / '.local/bin/dotfiles-theme'))
template = (repo / '.config/lnav/config.json.theme').read_text()
for name in expected:
    profile = json.loads((root / f'themes/{name}.json').read_text())
    config = json.loads(module['TOKEN'].sub(lambda match: profile[match[1]], template))
    identifier = profile['lnav']
    assert set(config['ui']['theme-defs']) == {'default', identifier}
    theme = config['ui']['theme-defs'][identifier]
    if 'color_map' in profile:
        colors = json.loads((root / 'themes' / profile['color_map']).read_text())
        adapted = json.loads(module['replace_colors'](json.dumps(theme), colors))
        assert adapted['vars']['bg0'] != theme['vars']['bg0']
        assert adapted['styles'] == theme['styles']
    assert config['ui']['theme'] == identifier
PY
print 'PASS: theme-neutral VisiData and lnav adapters preserve all three layouts'
