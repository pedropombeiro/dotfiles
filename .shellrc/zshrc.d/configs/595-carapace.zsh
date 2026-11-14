#!/usr/bin/env zsh

# Carapace adds completions with descriptions and error messages. Use it only
# for commands that have no other completion, so native and generated
# completions keep precedence.
(( $+commands[carapace] )) || return

# 320-generate-completions.zsh stores Carapace's command list in `_carapace`.
# Assigning `_comps` directly is what `compdef _carapace ...` does for plain
# commands, at a fraction of the cost for hundreds of names.
_carapace_fill_gaps() {
  setopt localoptions extendedglob
  local -a names covered fn=(_carapace)
  [[ -r $1 ]] || return
  names=(${=${(M)${(f)"$(<$1)"}:#\# carapace-commands: *}#\# carapace-commands: })
  covered=(${(k)_comps})
  names=(${names:|covered})
  # Fallback patterns such as `pip[0-9.]#` apply only without a `_comps` entry.
  (( $#_postpatcomps )) && names=(${names:#${~:-(${(kj:|:)_postpatcomps})}})
  _comps+=(${names:^^fn})
  unfunction _carapace_fill_gaps
}

# Run after the other deferred tasks register their completions, including
# git-extras and Atuin at the same priority.
_defer_shell_init 0c carapace "_carapace_fill_gaps ${(q)HOME}/.config/zsh/site-functions/_carapace"
