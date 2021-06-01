#!/usr/bin/env zsh

alias lg='lazygit'
alias gdp='printf "\`\`\`patch\n%s\n\`\`\`" "$(git diff)" | pbcopy'
alias sql2md='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias fgdku='cd ${GDK_ROOT}/gitlab && gdk update && rebase-all && bin/rspec spec/lib/expand_variables_spec.rb'
