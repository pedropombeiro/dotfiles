# Zsh cheat sheet

Configuration: [`~/.shellrc/zshrc.d/`](../../.shellrc/zshrc.d/). The shell uses
[zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode), so `Esc` switches to
normal mode. History search lives in the [Atuin sheet](atuin.md), and file
pickers live in the [fzf sheet](fzf.md).

## Memorize first

1. `Esc`, then `vv`, opens the command line in Neovim for long edits.
1. `!$` reuses the last argument, and `Space` expands it in place before you
   run the command.
1. `^old^new` reruns the previous command with a substitution.
1. `M-s` opens the sesh picker, and `Prefix Y` in tmux copies the command line.
1. `ci"`, `da(`, and `cs"'` edit quoted and bracketed arguments in normal mode.

## Vi-mode editing

Run these from normal mode.

| Goal                                           | Keys                | Notes                               |
| ---------------------------------------------- | ------------------- | ----------------------------------- |
| Edit the command line in `$EDITOR`             | `vv`                | Save and quit to return the result  |
| Change or delete inside quotes or brackets     | `ci"`, `di(`, `da[` | Text objects, as in Vim             |
| Change or delete surrounding quotes            | `cs"'` or `ds"`     |                                     |
| Surround a visual selection                    | `S"`                |                                     |
| Increment a number, or flip `true` and `false` | `C-a`               | `C-x` goes the other way            |
| Open the URL or path under the cursor          | `gx`                |                                     |
| Prefix-search older or newer commands          | `k` or `j`          | Matches what you typed before `Esc` |
| Open the Atuin search                          | `/`                 | `C-r` works in insert mode          |

In insert mode, `Up` and `Down` prefix-search history, `M-Backspace` deletes a
word, and `M-Left` and `M-Right` move by word.

## History expansion

Typing `Space` after an expansion replaces it in place. If you press `Enter`
first, `histverify` places the expanded command on the line, so press `Enter`
again to run it.

| Expansion        | Result                                             |
| ---------------- | -------------------------------------------------- |
| `!!`             | The previous command, as in `sudo !!`              |
| `!$` or `!^`     | The last or first argument of the previous command |
| `!*`             | Every argument of the previous command             |
| `!-2`            | The command before the previous one                |
| `!git`           | The latest command starting with `git`             |
| `^old^new`       | The previous command with `old` replaced by `new`  |
| `!!:gs/old/new/` | The previous command with every `old` replaced     |
| `!$:h` or `!$:t` | The directory or file name of the last argument    |

A command that starts with a space stays out of history.

## Custom functions

| Goal                                           | Command            | Notes                             |
| ---------------------------------------------- | ------------------ | --------------------------------- |
| Open Yazi and keep its final directory         | `fm`, `fm foo`     | `foo` resolves through zoxide     |
| Open LazyGit, YADM-aware                       | `lg`               |                                   |
| Run a shell or command in YADM's context       | `y`, `y git log`   |                                   |
| Push, or fetch with merged-branch alerts       | `gp`, `gf`, `gfa`  | YADM-aware in `~`                 |
| Delete merged or gone branches and worktrees   | `git_prune -n`     | `-n` previews; keeps `_` branches |
| Copy the diff as a Markdown patch block        | `gdp`              | Ready to paste into an MR or chat |
| Follow a log with syntax highlighting          | `t FILE`           | `FILE` is the log path            |
| Keep an SSH session reconnecting               | `ssh_persist HOST` | Retries on transport failures     |
| Run `bundle exec`, inside Caproni when present | `be rspec`         |                                   |
| Create a directory and enter it                | `mkcd DIR`         |                                   |

## Recipes

**Turn a long command into a script.** Recall it with `C-r`, press `Tab` to edit,
then `Esc` and `vv`. Neovim opens the command, ready to save under a new name
with `:w`.

**Rerun a command against another file.** After `nvim app/models/user.rb`, run
`git log -p !$` to inspect the same file.

**Share local changes for review.** Run `gdp` and paste the clipboard into the
merge request comment.
