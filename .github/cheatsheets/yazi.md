# Yazi cheat sheet

Configuration: [`~/.config/yazi/keymap.toml`](../../.config/yazi/keymap.toml).
Open Yazi with `fm`, which changes the shell directory on exit, or with
`<leader>F` from Neovim.

## Memorize first

1. `g c` lists files with Git changes, and `g /` lists Git-tracked files.
1. `Z` jumps through zoxide, and `z` jumps through fzf.
1. `r` with several files selected opens a bulk rename in your editor.
1. `m` saves a bookmark, and `'` jumps to one.
1. `Tab` spots the hovered file, showing its metadata, without leaving the list.

## Navigation and search

| Goal                                         | Keys                 | Notes                                  |
| -------------------------------------------- | -------------------- | -------------------------------------- |
| Jump to the Git repository root              | `g r`                |                                        |
| Browse Git-tracked or changed files          | `g /` or `g c`       | Flat lists across subdirectories       |
| Move in the parent directory without leaving | `[ [` or `] ]`       | Steps to the previous or next sibling  |
| Move by a relative count                     | `5 j`, `3 k`         | Relative numbers appear while counting |
| Search names or contents recursively         | `s` (fd) or `S` (rg) | `C-s` cancels the search               |
| Filter the current listing                   | `f`                  |                                        |
| Go back or forward in directory history      | `H` or `L`           |                                        |
| Follow the hovered symlink                   | `g f`                |                                        |
| Type a path with completion                  | `g Space`            |                                        |

## Selection and file operations

| Goal                                        | Keys                            | Notes                               |
| ------------------------------------------- | ------------------------------- | ----------------------------------- |
| Toggle the hovered file                     | `Space Space`                   | A lone `Space` is a prefix          |
| Select a range                              | `v`, then move                  | `V` unselects a range               |
| Select all, or invert the selection         | `C-a` or `C-r`                  |                                     |
| Bulk rename the selection                   | `r`                             | One file per line in `$EDITOR`      |
| Bulk create files                           | `A`                             | End a name with `/` for a directory |
| Symlink yanked files, relative              | `_`                             | `-` zooms instead                   |
| Archive the selection                       | `c a a`, `c a p` for a password | `c a l` sets the level              |
| Change permissions                          | `c m`                           |                                     |
| Copy the files or their contents            | `c c` or `c C`                  | `c v` pastes                        |
| Copy the directory path or file name        | `c d`, `c f`, or `c n`          | `c n` omits the extension           |
| Share the selection over croc               | `c s`                           |                                     |
| Diff the selection against the hovered file | `C-d`                           | Shows a patch                       |
| Open the selected files in Neovim diff mode | `C-t`                           | Runs `nvim -d`                      |
| Watch background copy and move tasks        | `w`                             |                                     |

## Preview and tools

| Goal                                      | Keys         | Notes                     |
| ----------------------------------------- | ------------ | ------------------------- |
| Maximize or restore the preview           | `T`          |                           |
| Scroll the preview                        | `J` or `K`   |                           |
| Zoom into an image preview                | `+` or `-`   |                           |
| Open Quick Look                           | `C-p`        | macOS                     |
| Show disk usage for the hovered path      | `Space d u`  | Runs `dua i`              |
| Follow a log file                         | `Space t f`  | Runs `tail -f`            |
| Open LazyGit                              | `Space t g`  |                           |
| Run a shell command on the selection      | `;` or `:`   | `:` waits for the command |
| Quit without changing the shell directory | `C-q` or `Q` |                           |

## Tabs

| Goal                                    | Keys           |
| --------------------------------------- | -------------- |
| Open the hovered directory in a new tab | `t t`          |
| Switch to tab 1 to 9                    | `t 1` to `t 9` |
| Switch to the previous or next tab      | `[ t` or `] t` |
| Swap a tab with its neighbor            | `{` or `}`     |
| Rename the tab                          | `t r`          |

## Recipes

**Review your uncommitted work.** Press `g c`, move through the changed files
with the preview open, and press `T` to read a long diff in full.

**Rename a batch of files.** Select them with `v`, press `r`, edit the names in
Neovim with macros or `:s`, then save and quit.

**Compare two configuration files.** Select both files with `Space Space` and
press `C-t` to open them in Neovim diff mode. For a quick patch preview instead,
select one file, hover the other, and press `C-d`.
