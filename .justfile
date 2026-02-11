default: pull update

[script]
pull:
    yadm fetch
    yadm reset --hard origin/master

@install:
    yadm bootstrap

@update:
    ~/.config/yadm/scripts/update.sh

@checkhealth:
    ~/.config/yadm/scripts/run-checks.zsh

@brew-dump:
    brew bundle dump --global --describe --force

@brew-cleanup:
    brew bundle cleanup ~/.Brewfile --force --file

@wifi-traffic:
    ssh ap-u6pro.infra.pombei.ro "tcpdump -np"

# Detect whether to use yadm or git.
[private]
git-cmd:
    #!/usr/bin/env sh
    if [ "$(pwd)" = "$HOME" ] || yadm status > /dev/null 2>&1; then
        echo yadm
    else
        echo git
    fi

# Push to the remote, using yadm or git as appropriate.
@push *ARGS='':
    {{ `just git-cmd` }} push {{ ARGS }}

# Generate a commit message and commit staged changes using opencode.
# Usage:
#   just commit                    # generate + commit staged changes

# just commit feat               # conventional commit with type
@commit TYPE='':
    ~/.local/bin/git-ai-commit-msg {{ if TYPE != '' { "--type " + TYPE } else { "" } }}

fix *FILES='':
    #!/usr/bin/env sh
    if [ -n "{{ FILES }}" ]; then
        yadm enter pre-commit run --files {{ FILES }} --hook-stage manual
    else
        yadm enter pre-commit run --all-files --hook-stage manual
    fi

lint *FILES='':
    #!/usr/bin/env sh
    if [ -n "{{ FILES }}" ]; then
        yadm enter pre-commit run --files {{ FILES }}
    else
        yadm enter pre-commit run --all-files
    fi
