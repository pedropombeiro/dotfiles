#!/usr/bin/env zsh
#
# Reject yadm alternates that are near-full copies of each other.
#
# Two non-template variants of the same file may share at most MAX_SHARED
# non-blank lines. Past that, move the shared content into a base file that the
# variants include, or into a template. See ~/.agents/docs/yadm-layout.md.
#
# Arguments are ignored: the check always covers every tracked alternate, so it
# also catches a variant whose sibling grew in an earlier commit.

setopt LOCAL_OPTIONS EXTENDED_GLOB

MAX_SHARED=50

# Files the owning tool writes to. A template would make those writes untracked
# and yadm would overwrite them, so these keep full-copy variants.
local -a EXCEPTIONS=(
  .Brewfile                                        # `mise run brew:dump`
  .config/iterm2/config/com.googlecode.iterm2.plist # iTerm2 preferences
  .config/opencode/opencode.json                    # OpenCode config updates
  .config/pgcli/config                              # pgcli `\ns` named queries
)

cd "$HOME" || exit 1

# (f) splits on newlines, (M) keeps only matching elements
local -a alts=( ${(M)${(f)"$(yadm ls-files)"}:#*\#\#*} )
local -A variants
local f base suffix
for f in "${alts[@]}"; do
  suffix=${f#*\#\#}
  # Skip directory alternates (a `/` after `##`)
  [[ $suffix == */* ]] && continue
  # Skip templates: `template`, `t`, or `yadm`, optionally with `.processor`
  [[ ",${suffix}," =~ ',(template|t|yadm)(\.[^,]*)?,' ]] && continue
  base=${f%%\#\#*}
  variants[$base]+="${f}"$'\n'
done

local -i failed=0 shared i j
local -a files
for base in ${(ok)variants}; do
  (( ${EXCEPTIONS[(Ie)$base]} )) && continue
  files=( ${(f)variants[$base]} )
  (( ${#files} < 2 )) && continue
  for (( i = 1; i < ${#files}; i++ )); do
    for (( j = i + 1; j <= ${#files}; j++ )); do
      shared=$(comm -12 \
        <(grep -v '^[[:space:]]*$' "${files[$i]}" | sort -u) \
        <(grep -v '^[[:space:]]*$' "${files[$j]}" | sort -u) | wc -l)
      if (( shared > MAX_SHARED )); then
        (( failed++ == 0 )) && echo "ERROR: yadm alternates share more than ${MAX_SHARED} lines:"
        echo "  ${files[$i]} <-> ${files[$j]} (${shared} shared lines)"
      fi
    done
  done
done

if (( failed )); then
  echo ""
  echo "Move the shared lines into an included base file or a template."
  echo "See ~/.agents/docs/yadm-layout.md."
  exit 1
fi
