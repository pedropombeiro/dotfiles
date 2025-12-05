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
