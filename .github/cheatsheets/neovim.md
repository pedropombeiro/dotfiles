# Neovim cheat sheet

Configuration: [`~/.config/nvim/`](../../.config/nvim/). `<leader>` is `Space`,
and `<localleader>` is `,`. Press `<leader><Tab>` to search every keymap.

## Memorize first

1. `<leader>fF` resumes the last picker with its query and position.
1. `C-q` inside any picker sends the results to the quickfix list.
1. `gra` previews code actions as diffs before applying them.
1. `<leader>ghs` stages the hunk under the cursor, or the selected lines.
1. `<leader>rl` repeats the last test run from any buffer.

## Pickers

| Goal                                       | Keys                         | Notes                            |
| ------------------------------------------ | ---------------------------- | -------------------------------- |
| Git grep, YADM-aware                       | `<leader>/`                  | Uses YADM in `~` and `~/.config` |
| Live grep with ripgrep                     | `<leader>fr`                 |                                  |
| Find recent files or open buffers          | `<leader>fh` or `<leader>fb` |                                  |
| Show the commits that touched this buffer  | `<leader>fgC`                |                                  |
| Search changed files, branches, or stashes | `<leader>fgs`, `fgb`, `fgS`  |                                  |
| Search the jump list, marks, or registers  | `<leader>f.`, `f'`, `f"`     |                                  |
| Search command or search history           | `<leader>f:` or `<leader>f/` |                                  |
| List every picker                          | `<leader>fS`                 |                                  |

Inside a picker:

| Goal                                      | Keys                    |
| ----------------------------------------- | ----------------------- |
| Select several items                      | `Tab`, or `C-a` for all |
| Send results or the selection to quickfix | `C-q`                   |
| Toggle hidden or ignored files            | `M-h` or `M-i`          |
| Switch between fuzzy filter and live grep | `C-g`                   |
| Open in a split or vertical split         | `C-s` or `C-v`          |
| Toggle the preview                        | `M-p`                   |

## Code navigation and refactoring

| Goal                                    | Keys                          | Notes                           |
| --------------------------------------- | ----------------------------- | ------------------------------- |
| Go to definitions in a picker           | `C-]` or `<leader>ld`         |                                 |
| List references, implementations, types | `grr`, `gri`, `grt`           | Neovim defaults                 |
| Jump to the next or previous reference  | `]w` or `[w`                  | No picker needed                |
| Rename a symbol across the project      | `grn` or `F2`                 |                                 |
| Preview and apply code actions          | `gra` or `<leader>ca`         | Works on a visual selection     |
| Run a code lens                         | `grx`                         |                                 |
| Search document or workspace symbols    | `<leader>ls` or `<leader>lws` |                                 |
| Toggle the symbol outline               | `C-\|`                        |                                 |
| Jump to the next or previous diagnostic | `]d` or `[d`                  | Opens a float                   |
| Format the buffer or selection          | `<leader>lf`                  | `<leader>lF` adds embedded code |
| Enable or disable format-on-save        | `[of` or `]of`                | Per buffer                      |
| Peek a closed fold                      | `<leader>k`                   |                                 |
| Align on a character                    | `ga`, a motion, the character | For example `gaip=`             |
| Increment dates, booleans, and versions | `C-a` or `C-x`                | `g C-a` increments a column     |

## Lists and diagnostics

| Goal                                       | Keys                         |
| ------------------------------------------ | ---------------------------- |
| Toggle workspace or buffer diagnostics     | `<leader>xw` or `<leader>xd` |
| Toggle the quickfix list in Trouble        | `<leader>xq`                 |
| Jump to the next or previous quickfix item | `]x` or `[x`                 |
| Jump to the first or last item             | `[X` or `]X`                 |
| Run a command on every quickfix entry      | `:cdo s/old/new/ \| update`  |

## Git

| Goal                                        | Keys                           | Notes                          |
| ------------------------------------------- | ------------------------------ | ------------------------------ |
| Jump between hunks                          | `[h` and `]h`                  | `[H` and `]H`: first and last  |
| Stage or reset a hunk or the selected lines | `<leader>ghs` or `<leader>ghr` |                                |
| Preview a hunk inline                       | `<leader>ghp`                  |                                |
| Select a hunk as a text object              | `ih`, as in `vih` or `dih`     |                                |
| Show the full blame for a line              | `<leader>ghb`                  | `[gb` enables inline blame     |
| Show deleted lines inline                   | `[gd`                          | `]gd` hides them               |
| Send all hunks to quickfix                  | `<leader>ghq`                  |                                |
| Diff against the index or `HEAD~`           | `<leader>ghd` or `<leader>ghD` |                                |
| Open the changes in a side-by-side diff     | `<leader>gd`                   | CodeDiff                       |
| Open the lines in GitLab                    | `:GBrowse`                     | `:GBrowse!` copies the URL     |
| Open LazyGit                                | `<leader>tg`                   | A zoomed tmux pane inside tmux |

## Tests, tasks, and tools

| Goal                                        | Keys                         |
| ------------------------------------------- | ---------------------------- |
| Run the nearest test or the whole file      | `<leader>rt` or `<leader>rf` |
| Repeat the last test run                    | `<leader>rl`                 |
| Open the test output or summary             | `<leader>ro` or `<leader>rr` |
| Rerun the file's tests on save              | `<leader>rw`                 |
| Run an Overseer task, or show the task list | `<leader>oo` or `<leader>ow` |
| Ask OpenCode about the cursor or selection  | `<leader>aa`                 |
| Pick an OpenCode action or review changes   | `<leader>as` or `<leader>ap` |
| Toggle or resume OpenCode                   | `<leader>ac` or `<leader>ar` |
| Open a scratch buffer                       | `<leader>-`                  |
| List the URLs in the buffer                 | `<leader>fu`                 |
| Open Yazi at the current file               | `<leader>F`                  |

## Recipes

**Replace across the project.** Run `<leader>/`, type the pattern, press `C-q`,
then `:cdo s/old/new/gc | update`.

**Commit part of a file.** Select the lines, press `<leader>ghs`, and review the
rest with `<leader>ghp` before committing.

**Find why a line changed.** Press `<leader>ghb` for the commit, then
`<leader>fgC` to read the surrounding history of the file.
