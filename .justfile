default: pull update

@pull:
    yadm fetch && \
      yadm reset --hard origin/master

@install:
    yadm bootstrap

@update:
    ~/.config/yadm/scripts/update.sh

@brew-dump:
    brew bundle dump -f --file=~/Brewfile --describe --tap --mas

@wifi-traffic:
    ssh ap-u6pro.infra.pombei.ro "tcpdump -np"
