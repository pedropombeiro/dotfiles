#!/usr/bin/env zsh

# Generate customized init per shell. The default output can be reused until
# either the executable or this configuration changes.
_shell_init_zoxide() {
  (( $+commands[zoxide] )) || return
  local bin=$commands[zoxide]
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zoxide/init.zsh"
  local header="" code=""
  if (( ${#${(k)parameters[(I)_ZO_*]}} )); then
    eval "$("$bin" init zsh --no-cmd)"
  else
    [[ -s $cache ]] && IFS= read -r header < "$cache"
    if [[ $header != "# zoxide-bin: $bin" || $cache -ot $bin || $cache -ot $_shell_zoxide_config ]]; then
      code=$("$bin" init zsh --no-cmd) || return
      [[ -n $code ]] || return
      local tmp="${cache}.tmp.$$"
      if mkdir -p "${cache:h}" && print -rl -- "# zoxide-bin: $bin" "$code" > "$tmp" && mv -f -- "$tmp" "$cache"; then
        source "$cache"
      else
        rm -f -- "$tmp"
        eval "$code"
      fi
    else
      source "$cache"
    fi
  fi
  alias j="__zoxide_z"
  alias jj="__zoxide_zi"
}
typeset -g _shell_zoxide_config="${(%):-%x}"
_defer_shell_init 0a zoxide '_shell_init_zoxide'
