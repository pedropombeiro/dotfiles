set quiet := true
set script-interpreter := ['sh', '-eu']

default: pull update

# ── Dotfiles ──────────────────────────────────────────────────────────

[confirm('This will discard local dotfile changes. Continue?')]
[doc('Fetch and hard-reset dotfiles to origin/master')]
[group('dotfiles')]
[script]
pull:
    yadm fetch
    yadm reset --hard origin/master

[doc('Bootstrap the dotfile environment')]
[group('dotfiles')]
install:
    yadm bootstrap

[doc('Run dotfile update scripts')]
[group('dotfiles')]
update:
    ~/.config/yadm/scripts/update.sh

[doc('Run dotfile health checks')]
[group('dotfiles')]
checkhealth:
    ~/.config/yadm/scripts/run-checks.zsh

# ── Git ───────────────────────────────────────────────────────────────

git_cmd := if path_exists(home_directory() / ".local/share/yadm/repo.git") == "true" { "yadm" } else { "git" }

[doc('Push to remote (auto-detects yadm vs git)')]
[group('git')]
push *ARGS='':
    {{ git_cmd }} push {{ ARGS }}

[doc('Generate an AI commit message and commit staged changes')]
[group('git')]
commit TYPE='':
    ~/.local/bin/git-ai-commit-msg {{ if TYPE != '' { "--type " + TYPE } else { "" } }}

[doc('Run pre-commit fixers (manual stage)')]
[group('git')]
[script]
fix *FILES='':
    if [ -n "{{ FILES }}" ]; then
        yadm enter pre-commit run --files {{ FILES }} --hook-stage manual
    else
        yadm enter pre-commit run --all-files --hook-stage manual
    fi

[doc('Run pre-commit linters')]
[group('git')]
[script]
lint *FILES='':
    if [ -n "{{ FILES }}" ]; then
        yadm enter pre-commit run --files {{ FILES }}
    else
        yadm enter pre-commit run --all-files
    fi

# ── Misc ──────────────────────────────────────────────────────────────

[doc('Dump current Homebrew packages to Brewfile')]
[group('brew')]
brew-dump:
    brew bundle dump --global --describe --force

[doc('Remove packages not in Brewfile')]
[group('brew')]
brew-cleanup:
    brew bundle cleanup ~/.Brewfile --force --file

[doc('Sniff Wi-Fi traffic from the AP')]
[group('network')]
wifi-traffic:
    ssh ap-u6pro.infra.pombei.ro "tcpdump -np"
