#!/usr/bin/env zsh

# OMZ libs: clipboard (needed by widgets), compfix (calls compaudit), completion
# settings (zstyles), directory helpers (aliases). All safe to defer since nothing
# in the synchronous startup path depends on them.
# OMZL::completion.zsh reads COMPLETION_WAITING_DOTS and clobbers WORDCHARS.
zinit wait'0' lucid for \
  OMZL::clipboard.zsh \
  OMZL::compfix.zsh \
  atinit'COMPLETION_WAITING_DOTS="true"; DISABLE_UNTRACKED_FILES_DIRTY="true"' \
  atload"WORDCHARS='_'" OMZL::completion.zsh \
  OMZL::directories.zsh

# Skip autosuggestions' automatic widget re-binding on every precmd (O(n) in widget count).
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Register history prefix search widgets early so zsh-autosuggestions can wrap
# them during its initial bind. The actual keybindings happen later in atuin.zsh.
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(
  history-beginning-search-backward-end
  history-beginning-search-forward-end
)

# Load syntax highlighting, wakatime, then autosuggestions via zinit turbo.
# Order matters: autosuggestions must load last so it wraps accept-line
# outermost (per FSH README). The ! prefix on atload ensures the function
# is tracked by zinit for proper replay.
zinit wait'0' lucid light-mode for \
  zdharma-continuum/fast-syntax-highlighting \
  atinit'ZSH_WAKATIME_BIN="$HOME/.wakatime/wakatime-cli"' sobolevn/wakatime-zsh-plugin \
  atload'!_zsh_autosuggest_start' zsh-users/zsh-autosuggestions

# fzf-tab: replace zsh completion menu with fzf popup
zinit wait'0a' lucid light-mode for \
  Aloxaf/fzf-tab

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:eza:*' fzf-preview '[[ -d $realpath ]] && eza -1 --color=always --icons $realpath || bat --color=always --style=numbers --line-range=:500 $realpath'
# Cache brew info output for 24h (86400s) to avoid slow network lookups on every tab
zstyle ':fzf-tab:complete:brew-(install|info|upgrade):*' fzf-preview 'CACHE="/tmp/brew-info-$word"; [[ -f $CACHE && $((EPOCHSECONDS - $(stat -f%m $CACHE))) -lt 86400 ]] || HOMEBREW_COLOR=1 brew info $word 2>/dev/null >$CACHE; cat $CACHE'
zstyle ':fzf-tab:complete:brew-(install|info|upgrade):*' fzf-flags --preview-window=right:50%:wrap:~3

# git: preview branches showing commits since the default branch (origin/HEAD..branch),
# fall back to the last 20 commits if no base, or show file diff for non-branch words
zstyle ':fzf-tab:complete:git:*' fzf-preview \
  'w=${word%% }; base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@refs/remotes/@@"); log=$(git log --oneline --graph --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" ${base:+$base..}$w 2>/dev/null); [[ -n $log ]] && echo $log || git log --oneline --graph --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" -n 20 $w 2>/dev/null || git diff --color=always -- $w 2>/dev/null | head -100'

# ipinfo uses bash-style `complete -C` for completions; bashcompinit bridges
# that into zsh's completion system. Uses null plugin for deferred turbo load.
# autoload +X loads the function immediately (not lazily) so bashcompinit runs at source time.
zinit wait lucid nocd for \
  atinit'autoload -U +X bashcompinit && bashcompinit' \
  atload'complete -o default -C /opt/homebrew/bin/ipinfo ipinfo' \
  zdharma-continuum/null

# OMZ completions only (no aliases)
zinit wait lucid as"completion" for \
  OMZP::yarn/_yarn \
  OMZP::redis-cli/_redis-cli

# Fix autosuggestion ghost text on accept-line. The autosuggestions clear
# widget sets POSTDISPLAY= but the terminal redraw (zle -R) runs after the
# inner accept-line has already committed the line, leaving suggestion text
# painted in default foreground. This outermost wrapper clears POSTDISPLAY
# and forces a redraw before calling the builtin accept-line.
_fix_autosuggest_accept_line() {
  _accept_line_and_clear_suggestion() {
    POSTDISPLAY=
    region_highlight=()
    zle -R
    zle .accept-line
  }
  zle -N accept-line _accept_line_and_clear_suggestion
}

zinit wait'0d' lucid nocd light-mode for \
  atload'_fix_autosuggest_accept_line' \
  zdharma-continuum/null
