#!/usr/bin/env bash

# General aliases
alias zinit-home="\$EDITOR \${XDG_DATA_HOME:-\$HOME/.local/share}/zinit"
# shellcheck disable=SC2142  # This pattern works in bash/zsh
alias mkcd='mkcd_impl() { mkdir -p "$1" && cd "$1" || return; }; mkcd_impl'
alias myip="curl http://ipecho.net/plain; echo"
alias vimdiff="vim -d"

# Tool-specific aliases
alias lzd='lazydocker'

# Format SQL from stdin via pg_format, wrap in a markdown code block, and copy to clipboard
alias sqlformat='pg_format --nocomment - | xargs -0 printf "\`\`\`sql\n%s\`\`\`" | pbcopy'
alias vim=nvim
alias xh='xh --style $XH_STYLE' # defined in ~/.shellrc/rc.d/_theme.sh
alias ls='eza'
alias la='eza --almost-all --long --group --classify=always --icons=always'

alias docker_ip='docker inspect -f "{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'

# opencode with optional per-project model via mise env
oc() {
  if [[ -z "$OPENCODE_MODEL" ]]; then
    opencode "$@"
    return
  fi

  case "$1" in
  run)
    shift
    opencode run --model "$OPENCODE_MODEL" "$@"
    ;;
  upgrade | update | uninstall | acp | api | debug | auth | mcp | plugin | models | stats | mini | session | service | reload | pair | serve)
    # --standalone is a root-only flag, so subcommands run unchanged.
    opencode "$@"
    ;;
  *)
    # The interactive TUI has no --model flag. The inline config overrides the
    # top-level model, and --standalone runs a private server that sees this
    # environment instead of the shared background service's.
    OPENCODE_CONFIG_CONTENT="{\"model\":\"$OPENCODE_MODEL\"}" opencode --standalone "$@"
    ;;
  esac
}

# Include custom aliases
if [[ -f ~/.aliases.local ]]; then
  # shellcheck source=/dev/null
  source ~/.aliases.local
fi
