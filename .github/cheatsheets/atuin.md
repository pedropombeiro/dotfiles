# Atuin cheat sheet

Configuration: [`~/.config/atuin/config.toml`](../../.config/atuin/config.toml)
and [`590-atuin.zsh`](../../.shellrc/zshrc.d/configs/590-atuin.zsh).

## How this setup behaves

- `C-r` in insert mode, or `/` in Zsh normal mode, opens the Atuin search.
- `Up` doesn't open Atuin. It runs Zsh prefix search through local history:
  type `git re` and press `Up` or `Down` to cycle commands that start with it.
  In normal mode, `k` and `j` do the same.
- The search starts filtered to the **current host**, with fuzzy matching.
- `Enter` runs the selected command immediately. `Tab` places it on the command
  line for editing.
- History ignores commands that export tokens, secrets, or passwords, and
  commands that reference 1Password items.

## Memorize first

1. `C-r` inside the search cycles the filter: host, workspace, global, session,
   and directory.
1. `Tab` retrieves a command for editing instead of running it.
1. `C-o` opens the inspector, with every run of the command and its session.
1. `M-1` to `M-9` pick a visible result by its number.
1. `'`, `^`, `$`, and `!` refine a fuzzy query.

## Search controls

| Goal                                           | Keys           |
| ---------------------------------------------- | -------------- |
| Cycle the filter mode                          | `C-r`          |
| Cycle the search mode, such as fuzzy or prefix | `C-s`          |
| Copy the selected command to the clipboard     | `C-y`          |
| Show the commands around the selected one      | `C-a c`        |
| Delete the selected history entry              | `C-a d`        |
| Delete every entry matching the command        | `C-a D`        |
| Open the inspector                             | `C-o`          |
| Return to the original command line            | `Esc` or `C-g` |

## Fuzzy query syntax

| Query        | Matches                                 |
| ------------ | --------------------------------------- |
| `'deploy`    | Commands containing exactly `deploy`    |
| `^git`       | Commands starting with `git`            |
| `.json$`     | Commands ending with `.json`            |
| `!rspec`     | Commands not containing `rspec`         |
| `^rails !db` | Combined terms, all of which must match |

## Inspector

| Goal                                | Keys           |
| ----------------------------------- | -------------- |
| Switch to Runs, Session, or Stats   | `r`, `s`, `t`  |
| Delete the selected run             | `C-d`          |
| Edit the command without running it | `Tab`          |
| Return to the search                | `C-o` or `Esc` |

## Commands

| Goal                                   | Command                            |
| -------------------------------------- | ---------------------------------- |
| Show your most frequent commands       | `atuin stats`                      |
| List failed commands in this directory | `atuin search --exit 1 --cwd .`    |
| List commands from the last day        | `atuin search --after "yesterday"` |
| Remove matching entries in bulk        | `atuin search --delete QUERY`      |
| Check sync status                      | `atuin status`                     |

`QUERY` is the search text. Run the same `atuin search` without `--delete`
first to review the matches.

## Recipes

**Recover a command from another machine.** Press `C-r`, then `C-r` again until
the filter shows `GLOBAL`, and type part of the command.

**Rerun the command that worked earlier in this project.** Press `C-r` and cycle
to `WORKSPACE`, which scopes results to the current Git repository.

**Remove a leaked secret.** Search for it, press `C-a D` to delete every
matching entry, and rotate the secret.
