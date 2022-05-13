#!/usr/bin/env bash

alias lg='lazygit --use-config-dir ~/.config/lazygit'
alias ly='lazygit --use-config-dir ~/.config/lazygit --work-tree ~ --git-dir ~/.local/share/yadm/repo.git'
alias gdp='printf "\`\`\`patch\n%s\n\`\`\`" "$(git diff)" | pbcopy'

# Allow using y alias to run commands in the context of the YADM worktree
function y() {
  if [ $# -eq 0 ]; then
    yadm enter "$SHELL"
  else
    yadm enter "$SHELL -i -c '$*'"
  fi
}

# Delete all remote tracking Git branches where the upstream branch has been deleted
alias git_prune="git fetch --prune && git branch -vv | grep -E '(origin|security)/.*: gone]' | awk '{print \$1}' | grep -v '^_.*$' | xargs git branch -D"

alias rr=ranger
alias sqlformat='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias vim=nvim
alias xh='xh -s monokai'
command -v lsd >/dev/null && alias ls='lsd'

