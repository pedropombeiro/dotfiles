#!/usr/bin/env bash

alias lzd='lazydocker'

# Delete all remote tracking Git branches where the upstream branch has been deleted
alias git_prune="git fetch --prune && git branch -vv | grep -E '(origin|security)/.*: gone]' | awk '{print \$1}' | grep -v '^_.*$' | xargs git branch -D"

alias sqlformat='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias vim=nvim
alias xh='xh --style $XH_STYLE' # defined in ~/.shellrc/rc.d/_theme.sh
alias ls='eza'
alias la='eza --almost-all --long --classify=always --icons=always'

alias docker_ip='docker inspect -f "{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
