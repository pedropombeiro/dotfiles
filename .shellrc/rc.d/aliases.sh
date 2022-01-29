#!/usr/bin/env zsh

alias lg='[[ ${PWD} = ${HOME} ]] && lazygit -g $HOME/.local/share/yadm/repo.git -w ~ || lazygit'
alias gdp='printf "\`\`\`patch\n%s\n\`\`\`" "$(git diff)" | pbcopy'
alias sqlformat='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias vim=nvim
