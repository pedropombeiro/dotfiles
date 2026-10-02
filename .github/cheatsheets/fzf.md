# fzf cheat sheet

Configuration: [`~/.shellrc/rc.d/fzf.sh`](../../.shellrc/rc.d/fzf.sh) and
[`591-fzf.zsh`](../../.shellrc/zshrc.d/configs/591-fzf.zsh). Atuin owns `C-r`, so
fzf doesn't bind history search.

## Memorize first

1. `C-t` inserts one or more file paths at the cursor.
1. `M-c` changes into a directory picked from the tree below.
1. `C-g` inserts one or more Git branch names at the cursor.
1. `**` followed by `Tab` starts fuzzy completion for most arguments.
1. `C-/` toggles the `bat` preview, which starts hidden.

## Shell widgets

| Goal                                 | Keys  | Notes                                  |
| ------------------------------------ | ----- | -------------------------------------- |
| Insert file paths                    | `C-t` | `Tab` marks several files              |
| Change into a subdirectory           | `M-c` |                                        |
| Insert local and remote branch names | `C-g` | Custom widget; doesn't switch branches |

## Fuzzy completion

Type `**` where an argument goes, then press `Tab`.

| Example                           | Completes                         |
| --------------------------------- | --------------------------------- |
| `nvim **<Tab>`                    | Files below the current directory |
| `nvim src/**<Tab>`                | Files below `src/`                |
| `cd **<Tab>`                      | Directories                       |
| `kill -9 **<Tab>`                 | Processes, with a preview         |
| `ssh **<Tab>`                     | Hosts from SSH configuration      |
| `export **<Tab>`, `unset **<Tab>` | Environment variable names        |

## Query syntax

| Query             | Matches                                        |
| ----------------- | ---------------------------------------------- |
| `'spec`           | Exactly `spec`, not a fuzzy match              |
| `^app`            | Items starting with `app`                      |
| `.rb$`            | Items ending with `.rb`                        |
| `!test`           | Items not containing `test`                    |
| `rb$ \| lua$`     | Items ending with either extension             |
| `^app .rb$ !spec` | Space-separated terms, all of which must match |

## Inside the finder

| Goal                 | Keys                       |
| -------------------- | -------------------------- |
| Mark several items   | `Tab` or `Shift+Tab`       |
| Toggle the preview   | `C-/`                      |
| Scroll the preview   | `Shift+Up` or `Shift+Down` |
| Move through results | `C-j` and `C-k`            |
| Clear the query      | `C-u`                      |

## Recipes

**Open several related files.** Type `nvim` and a space, then press `C-t`.
Type `^app .rb$ !spec`, mark the files with `Tab`, and press `Enter`.

**Delete merged branches by hand.** Type `git branch -D` and a space, press
`C-g`, and mark the branches with `Tab`.
