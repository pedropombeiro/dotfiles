---
name: hk-yadm
description: Apply Pedro's YADM-specific hk rules. Use when editing ~/hk.pkl or diagnosing dotfiles hooks, bare-repository behavior, stash recursion, or global hk hook commands. Use alongside hk-configure or hk-debug.
---

# hk for YADM dotfiles

Load `hk-configure` for configuration work or `hk-debug` for diagnosis. Read
`~/.agents/docs/hk.md` for the dotfiles configuration and global hook details.
These local rules take precedence over generic repository setup advice.

## Preserve the dotfiles setup

- Use `yadm` for status and diffs, and `yadm enter hk ...` for commands that
  need Git context. `$HOME` is the work tree of YADM's bare repository. hk
  requires v2.1.0 or later for the current configuration.
- Keep `HK_STASH_UNTRACKED=false` in `~/hk.pkl` to avoid scanning the entire
  home directory for untracked files.
- Keep `stash = "none"` on the `pre-commit` hook. Other hooks, including `fix`,
  default to no stashing in hk v2. The global hooks
  can re-enter hk during its internal Git stash operations. Fixers can also
  affect unstaged content with stashing disabled, so inspect both diffs.
- Preserve the existing global config-based hooks. Re-running
  `hk install --global` overwrites the local command guards that allow Git to
  run when hk is absent from `PATH`. See the repair procedure in the hk docs.
- Add shared checks to `fast_steps`. Preserve the Pkl package pins unless the
  task requires an upgrade or a newer schema feature.
- Keep narrow exclusions for upstream skill directories and symlinks so
  filesystem-walking fixers cannot modify their targets. Locally authored
  skills, including this one, receive normal checks.

## Verify changes

```bash
yadm enter hk validate
yadm enter hk check --plan
yadm enter hk check --check --step STEP PATH
yadm diff
yadm diff --cached
```

Replace `STEP` and `PATH` with the relevant check and changed file. Run
`yadm enter hk check --all` when full dotfiles validation is required.

## Update bundled skills

`hk-configure` and `hk-debug` come from the reviewed hk release through mise.
Keep `skills.auto_sync` disabled. After an upgrade, follow the review and manual
sync procedure in `~/.agents/docs/mise.md` before activating the new versions.
