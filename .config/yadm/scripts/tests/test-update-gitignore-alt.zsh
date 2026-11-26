#!/usr/bin/env zsh

# Exercise update-gitignore-alt.zsh sorting, idempotence, and locale isolation.
emulate -LR zsh
setopt err_exit

tests_dir=${0:A:h}
scripts_dir=${tests_dir:h}
source "$tests_dir/lib/test-helpers.zsh"

test_sandbox
trap test_cleanup EXIT

test_stub yadm <<'EOF'
#!/usr/bin/env zsh
[[ $1 == ls-files ]] || exit 1
cat <<'FILES'
.agents/docs/gdkbox-gcp.md##class.Work,extension.md
.Brewfile##os.Darwin,class.Personal
.Brewfile##os.Darwin,class.Work
.config/opencode/opencode.json##template
.config/opencode/opencode-notifier.json##template
.default-gems##os.Darwin
.hammerspoon/audio.lua##os.Darwin
.shellrc/zshrc.d/functions/diff_structure##class.Work
.shellrc/zshrc.d/functions/fgdku##class.Work
.shellrc/zshrc.d/functions/_fgdku##class.Work
Developer/gitlab.com/opencode.jsonc##class.Work
README.md
FILES
EOF

expected=$'# Static header\n*.log\n\n# BEGIN yadm-alt (auto-generated, do not edit)\n.Brewfile\n.agents/docs/gdkbox-gcp.md\n.config/opencode/opencode-notifier.json\n.config/opencode/opencode.json\n.default-gems\n.hammerspoon/audio.lua\n.shellrc/zshrc.d/functions/_fgdku\n.shellrc/zshrc.d/functions/diff_structure\n.shellrc/zshrc.d/functions/fgdku\nDeveloper/gitlab.com/opencode.jsonc\n# END yadm-alt\n\n# Static footer\n*.tmp'

# Seed .gitignore with pre-existing markers and surrounding content.
print -r -- $'# Static header\n*.log\n\n# BEGIN yadm-alt (auto-generated, do not edit)\nstale-entry\n# END yadm-alt\n\n# Static footer\n*.tmp' > "$HOME/.gitignore"

# Run with LC_ALL=en_US.UTF-8 and confirm C-locale ordering without leaking LC_ALL.
zsh -df -c '
  set -e
  export LC_ALL=en_US.UTF-8
  source "$1/update-gitignore-alt.zsh" >/dev/null
  [[ $LC_ALL == en_US.UTF-8 ]] || { print -ru2 "LC_ALL leaked: $LC_ALL"; exit 1; }
' _ "$scripts_dir"
test_assert_equal 'C-locale sort under LC_ALL=en_US.UTF-8' "$expected" "$(<"$HOME/.gitignore")"

# Run again with LC_ALL unset and LC_COLLATE=en_US.UTF-8 to confirm idempotence and no leak.
zsh -df -c '
  set -e
  unset LC_ALL
  export LANG=en_US.UTF-8 LC_COLLATE=en_US.UTF-8
  source "$1/update-gitignore-alt.zsh" >/dev/null
  (( ! ${+LC_ALL} )) || { print -ru2 "LC_ALL leaked when originally unset: $LC_ALL"; exit 1; }
  [[ $LC_COLLATE == en_US.UTF-8 ]] || { print -ru2 "LC_COLLATE changed: $LC_COLLATE"; exit 1; }
' _ "$scripts_dir"
test_assert_equal 'idempotent under LC_COLLATE=en_US.UTF-8' "$expected" "$(<"$HOME/.gitignore")"

print 'PASS: update-gitignore-alt sorts deterministically under C locale without leaking locale vars'
