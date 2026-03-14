#!/usr/bin/env zsh

if command -v tmux >/dev/null; then
  export ZSH_TMUX_CONFIG="$HOME/.config/tmux/tmux.conf"
  export ZSH_TMUX_DEFAULT_SESSION_NAME="$(hostname)"
  export ZSH_TMUX_FIXTERM_WITH_256COLOR="tmux-256color"
  export ZSH_TMUX_ITERM2=false
  export ZSH_TMUX_UNICODE=true

  local _platform_conf="${0:A:h}/tmux.platform.zsh"
  [[ -f "$_platform_conf" ]] && source "$_platform_conf"

  # Load tmux plugin via zinit.
  # zinit's snippet mode only fetches the main file; the plugin also sources tmux.extra.conf
  # at runtime, so we manually download it into the snippet directory on clone/update.
  zinit ice atclone'curl -sLo tmux.extra.conf https://github.com/ohmyzsh/ohmyzsh/raw/master/plugins/tmux/tmux.extra.conf' \
            atpull'%atclone'
  zinit snippet OMZP::tmux
fi
