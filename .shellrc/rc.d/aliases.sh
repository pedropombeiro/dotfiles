#!/usr/bin/env bash

alias lg=lazygit
alias ly='lazygit -ucd ~/.local/share/yadm/lazygit -w ~ -g ~/.local/share/yadm/repo.git'
alias gdp='printf "\`\`\`patch\n%s\n\`\`\`" "$(git diff)" | pbcopy'

# Delete all remote tracking Git branches where the upstream branch has been deleted
alias git_prune="git fetch --prune && git branch -vv | grep 'origin/.*: gone]' | awk '{print \$1}' | xargs git branch -d"

alias sqlformat='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias rr=ranger
alias vim=nvim

