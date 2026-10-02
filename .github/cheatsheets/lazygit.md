# LazyGit cheat sheet

Configuration: [`~/.config/lazygit/config.yml`](../../.config/lazygit/config.yml).
Open it with `lg`, `Prefix l` in tmux, or `<leader>tg` in Neovim. All three use
YADM in `~` and `~/.config`. Press `?` in any panel for its bindings.

## Memorize first

1. `Enter` on a file opens the staging view, where `Space` stages single lines.
1. `C-f` on a staged change finds the commit it belongs to, for a fixup.
1. `A` on a commit amends the staged changes into it, even deep in history.
1. `S` on a commit squashes every fixup commit above it.
1. `z` undoes the last action through the reflog, and `C-z` redoes it.

## Files and staging

| Goal                                     | Keys                  | Notes                             |
| ---------------------------------------- | --------------------- | --------------------------------- |
| Stage individual lines or a range        | `Enter`, then `Space` | `v` selects a range first         |
| Stage the whole hunk                     | `a`, then `Space`     | Toggles hunk selection            |
| Switch between unstaged and staged sides | `Tab`                 | In the staging view               |
| Edit a hunk in the editor before staging | `E`                   |                                   |
| Find the base commit for a fixup         | `C-f`                 | Selects it in Commits             |
| Generate a commit message with OpenCode  | `C-g`                 | Prefills the next commit          |
| Write a conventional commit              | `C-v`                 | Prompts for type, scope, and body |
| Commit while skipping hooks              | `w`                   |                                   |
| Filter by status                         | `C-b`                 | For example, only untracked files |
| Stash with options                       | `S`                   | For example, keep the index       |
| Open the reset menu                      | `D`                   | Includes nuking the working tree  |
| Diff in Beyond Compare                   | `B`                   |                                   |

## Commit surgery

| Goal                                          | Keys                        | Notes                               |
| --------------------------------------------- | --------------------------- | ----------------------------------- |
| Create a fixup commit for the selection       | `F`                         | Stage changes first                 |
| Mark a commit as a fixup or squash            | `f` or `s`                  | Applies during the rebase           |
| Move a commit down or up                      | `C-j` or `C-k`              |                                     |
| Edit, reword, or drop a commit                | `e`, `r`, or `d`            | `R` rewords in the editor           |
| Start an interactive rebase from a commit     | `i`                         | Then queue `e`, `s`, `f`, and `d`   |
| Mark a base commit, then rebase onto a branch | `B`, then `r` on the branch | Rebases only commits above the base |
| Copy commits and paste them elsewhere         | `C`, then `V`               | Cherry-pick across branches         |
| Revert a commit                               | `t`                         |                                     |
| Add a co-author or reset the author           | `a`                         |                                     |
| Copy the hash, message, or URL                | `y`                         |                                     |
| Start a bisect                                | `b`                         |                                     |
| Change the log order or graph                 | `C-l`                       |                                     |

## Custom patches

Build a patch from parts of existing commits.

1. Press `Enter` on a commit to list its files.
1. Press `Space` on a file, or `Enter` and then `Space` on lines, to add them to
   the patch.
1. Press `C-p` and choose an action, such as removing the patch from the commit,
   moving it into a new commit, or applying it to the working tree.

## Branches, remotes, and history

| Goal                              | Keys                              | Notes                       |
| --------------------------------- | --------------------------------- | --------------------------- |
| Filter history by path or author  | `C-s`                             | Shows only matching commits |
| Diff any two refs                 | `W` on one ref, then pick another | `W` again exits diff mode   |
| Push with GitLab options          | `Ctrl+Shift+E`                    | Skip CI or create an MR     |
| Open the branch's merge request   | `G`                               | Local branches; uses `glab` |
| Fast-forward without checking out | `f`                               | Local branches              |
| Set the upstream                  | `u`                               |                             |
| Create a worktree                 | `w`                               | Branches panel              |
| Pop or apply a stash              | `g` or `Space`                    | Stash panel                 |
| Switch to a recent repository     | `C-r`                             |                             |
| Run a shell command               | `:`                               |                             |
| Enlarge the focused panel         | `+` or `_`                        |                             |

## Recipes

**Fix a typo in an older commit.** Stage the fix, press `C-f` to find the
commit, then `A` to amend it into that commit. LazyGit rebases the commits
above it.

**Split a commit.** Press `Enter` on the commit, add the files to move with
`Space`, then press `C-p` and choose to move the patch into a new commit.

**Clean up before pushing.** Create fixups with `F` while you work, then press
`S` on the oldest commit of the branch to squash them all.
