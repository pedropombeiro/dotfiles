#!/usr/bin/env zsh

# Graceful no-op when atuin is not yet installed (e.g. fresh system before `mise install`)
(($+commands[atuin])) || return

# Cache `atuin init zsh` output to avoid ~30ms eval overhead on every shell startup.
# Regenerates when the atuin binary is newer (i.e. after upgrades).
_atuin_init="${XDG_DATA_HOME:-$HOME/.local/share}/atuin/init.zsh"

# Regenerate when: missing or empty, binary was upgraded, or this script was updated (e.g. yadm pull).
# ${(%):-%x} is a zsh prompt expansion that resolves to the current script's file path.
if [[ ! -s "$_atuin_init" || "$_atuin_init" -ot "$commands[atuin]" || "$_atuin_init" -ot "${(%):-%x}" ]]; then
  mkdir -p "${_atuin_init:h}"
  # --disable-up-arrow so we can bind up-arrow to native prefix search below,
  # while Ctrl-R still opens the Atuin TUI.
  _atuin_init_tmp="${_atuin_init}.tmp.$$"
  if atuin init zsh --disable-up-arrow >"$_atuin_init_tmp" && [[ -s "$_atuin_init_tmp" ]]; then
    mv "$_atuin_init_tmp" "$_atuin_init"
  else
    rm -f "$_atuin_init_tmp"
  fi
  unset _atuin_init_tmp
fi

# Up-arrow / k: inline prefix search with cursor at end of line.
# Ctrl-R: Atuin TUI (bound by atuin init).
# Widgets are created in 510-common-plugins.zsh (before autosuggestions) so they
# get wrapped for autosuggest clear. Here we just source atuin and bind keys.
_atuin_setup_keybindings() {
  [[ -s "$1" ]] || return
  source "$1"

  # Do not replace the native history widgets if cache generation failed.
  (($+functions[_atuin_search] && $+functions[_atuin_search_viins])) || return

  # Atuin sets LBUFFER/RBUFFER from the TUI selection and calls `zle accept-line`
  # without clearing POSTDISPLAY first. Autosuggestions' accept-line wrapper sees
  # cursor-at-end + non-empty POSTDISPLAY and appends the ghost text to the buffer,
  # producing e.g. `atuin stats --help stats --help`. Wrap the atuin search widgets
  # (the two bound by `_atuin_rebind_keys` below) to clear POSTDISPLAY before the
  # inner widget runs so the stale suggestion is gone by the time atuin calls
  # `zle accept-line`.
  _atuin_search_clear() {
    POSTDISPLAY=
    _atuin_search "$@"
  }
  _atuin_search_viins_clear() {
    POSTDISPLAY=
    _atuin_search_viins "$@"
  }
  zle -N atuin-search _atuin_search_clear
  zle -N atuin-search-viins _atuin_search_viins_clear

  _atuin_rebind_keys
}

# zsh-vi-mode resets keymaps when it initialises and clobbers ^R with
# history-incremental-search-backward. Unqualified `bindkey` calls also land in
# whichever keymap is `main` at the time, which is emacs before zsh-vi-mode
# switches it to viins. Bind each keymap explicitly, and rerun from both
# zvm_after_init (eager) and zvm_after_lazy_keybindings (first switch to normal
# mode) so the bindings survive.
_atuin_rebind_keys() {
  (($+functions[_atuin_search] && $+functions[_atuin_search_viins])) || return
  bindkey -M emacs '^r' atuin-search
  bindkey -M viins '^r' atuin-search-viins
  bindkey -M vicmd '/' atuin-search

  # Up/Down arrows: prefix search, in both normal/xterm and application/keypad modes
  local keymap
  for keymap in emacs viins vicmd; do
    bindkey -M $keymap '^[[A' history-beginning-search-backward-end
    bindkey -M $keymap '^[OA' history-beginning-search-backward-end
    bindkey -M $keymap '^[[B' history-beginning-search-forward-end
    bindkey -M $keymap '^[OB' history-beginning-search-forward-end
  done
  bindkey -M vicmd 'k' history-beginning-search-backward-end
  bindkey -M vicmd 'j' history-beginning-search-forward-end
}
zvm_after_init_commands+=(_atuin_rebind_keys)
zvm_after_lazy_keybindings_commands+=(_atuin_rebind_keys)

# Deferred load (wait'0c') so atuin binds after fzf (wait'0b') and zsh-vi-mode
_defer_shell_init 0c atuin "_atuin_setup_keybindings ${(q)_atuin_init}"

unset _atuin_init
