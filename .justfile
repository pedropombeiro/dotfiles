default: pull update

@pull:
    yadm fetch && \
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

@fix *FILES='':
    #!/usr/bin/env bash
    if [ -n "{{FILES}}" ]; then \
        yadm enter pre-commit run --files {{FILES}} --hook-stage manual; \
    else \
        yadm enter pre-commit run --all-files --hook-stage manual; \
    fi

@lint *FILES='':
    #!/usr/bin/env bash
    if [ -n "{{FILES}}" ]; then \
        yadm enter pre-commit run --files {{FILES}}; \
    else \
        yadm enter pre-commit run --all-files; \
    fi
