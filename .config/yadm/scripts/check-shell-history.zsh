#!/usr/bin/env zsh

# Check history policy independently of plugin loading and startup order.
emulate -LR zsh
setopt err_return pipefail
root=${0:A:h:h:h:h}
temporary=$(mktemp -d "${TMPDIR:-/tmp}/shell-history.XXXXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
export HISTFILE="$temporary/history"
source "$root/.shellrc/zshrc.d/configs/630-history.zsh"

fail() { print -ru2 -- "$*"; exit 1; }
for text in 'op read op://vault/item/field' 'export API_TOKEN=example' \
    'export APP_SECRET=example' 'export PASSWORD=example' 'echo /1PEexample' ' hidden'; do
  _shell_history_filter "$text" && fail "History admitted excluded pattern: $text"
done
_shell_history_filter 'git status' || fail 'History rejected an ordinary command'
[[ -o sharehistory && ! -o incappendhistory ]] || fail 'Conflicting history options'
[[ -o histignorespace && -o histverify ]] || fail 'Existing history behavior lost'

# History-file writes require an interactive shell. -df avoids all startup files.
zsh -dfi -c '
  source "$1"
  print -s -- "git status"
  print -s -- "op read op://vault/item/field"
  print -s -- "export API_TOKEN=example"
  fc -W "$HISTFILE"
' zsh "$root/.shellrc/zshrc.d/configs/630-history.zsh"
contents=$(<"$HISTFILE")
[[ $contents == *'git status'* ]] || fail 'Ordinary history was not persisted'
[[ $contents != *op://* && $contents != *API_TOKEN* ]] || fail 'Excluded history was persisted'
print -r -- 'Native history filtering, persistence, and sharing options: passed'
