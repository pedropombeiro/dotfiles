#!/usr/bin/env zsh

# Graceful no-op when atuin is not yet installed (e.g. fresh system before `mise install`)
(( $+commands[atuin] )) || return

# Cache `atuin init zsh` output to avoid ~30ms eval overhead on every shell startup.
# Regenerates when the atuin binary is newer (i.e. after upgrades).
_atuin_init="${XDG_DATA_HOME:-$HOME/.local/share}/atuin/init.zsh"

# Regenerate when: missing, binary was upgraded, or this script was updated (e.g. yadm pull).
# ${(%):-%x} is a zsh prompt expansion that resolves to the current script's file path.
if [[ ! -f "$_atuin_init" || "$_atuin_init" -ot "$commands[atuin]" || "$_atuin_init" -ot "${(%):-%x}" ]]; then
  mkdir -p "${_atuin_init:h}"
  # --disable-up-arrow so we can bind up-arrow to native prefix search below,
  # while Ctrl-R still opens the Atuin TUI.
  atuin init zsh --disable-up-arrow >"$_atuin_init"
fi

# Up-arrow / k: inline prefix search with cursor at end of line.
# Ctrl-R: Atuin TUI (bound by atuin init).
# Widgets are created in common-plugins.zsh (before autosuggestions) so they
# get wrapped for autosuggest clear. Here we just source atuin and bind keys.
_atuin_setup_keybindings() {
  source "$1"

  _atuin_rebind_ctrl_r
  bindkey '^[[A' history-beginning-search-backward-end  # Up arrow (normal/xterm mode)
  bindkey '^[OA' history-beginning-search-backward-end  # Up arrow (application/keypad mode)
  bindkey '^[[B' history-beginning-search-forward-end   # Down arrow (normal/xterm mode)
  bindkey '^[OB' history-beginning-search-forward-end   # Down arrow (application/keypad mode)
  bindkey -M vicmd 'k' history-beginning-search-backward-end
  bindkey -M vicmd 'j' history-beginning-search-forward-end
}

# zsh-vi-mode clobbers ^R with history-incremental-search-backward when it
# (re)initialises keymaps. Hook into both zvm_after_init (eager) and
# zvm_after_lazy_keybindings (deferred first keymap switch) to reclaim ^R.
_atuin_rebind_ctrl_r() {
  bindkey -M emacs '^r' atuin-search
  bindkey -M viins '^r' atuin-search-viins
  bindkey -M vicmd '/' atuin-search
}
zvm_after_init_commands+=(_atuin_rebind_ctrl_r)
zvm_after_lazy_keybindings_commands+=(_atuin_rebind_ctrl_r)

# Deferred load (wait'0c') so atuin binds after fzf (wait'0b') and zsh-vi-mode
zinit wait'0c' lucid nocd light-mode for \
  atload"_atuin_setup_keybindings $_atuin_init" \
  zdharma-continuum/null

unset _atuin_init
