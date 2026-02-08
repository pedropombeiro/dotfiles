#!/usr/bin/env bash

# General aliases
alias zinit-home="\$EDITOR \${XDG_DATA_HOME:-\$HOME/.local/share}/zinit"
# shellcheck disable=SC2142  # This pattern works in bash/zsh
alias mkcd='mkcd_impl() { mkdir -p "$1" && cd "$1" || return; }; mkcd_impl'
alias myip="curl http://ipecho.net/plain; echo"
alias vimdiff="vim -d"

# Tool-specific aliases
alias lzd='lazydocker'
alias lnav='TERM=xterm-256color lnav'  # notcurses doesn't recognize TERM=wezterm

# Delete all remote tracking Git branches where the upstream branch has been deleted
# shellcheck disable=SC2142  # This pattern works in bash/zsh
alias git_prune='git_prune_impl() { git fetch --prune && git branch -vv | grep -E "(origin|security)/.*: gone]" | awk "{print \$1}" | grep -v "^_.*\$" | xargs git branch -D; }; git_prune_impl'

alias sqlformat='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias vim=nvim
alias xh='xh --style $XH_STYLE' # defined in ~/.shellrc/rc.d/_theme.sh
alias ls='eza'
alias la='eza --almost-all --long --group --classify=always --icons=always'

alias docker_ip='docker inspect -f "{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'

# opencode with optional per-project model via mise env
oc() {
  if [[ -n "$OPENCODE_MODEL" ]]; then
    opencode --model="$OPENCODE_MODEL" "$@"
  else
    opencode "$@"
  fi
}

# Include custom aliases
if [[ -f ~/.aliases.local ]]; then
  # shellcheck source=/dev/null
  source ~/.aliases.local
fi
