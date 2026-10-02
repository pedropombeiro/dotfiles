# zoxide cheat sheet

Configuration: [`505-zoxide.zsh`](../../.shellrc/zshrc.d/configs/505-zoxide.zsh).
zoxide starts with `--no-cmd`, so this setup uses `j` and `jj` instead of `z`
and `zi`. Plain `cd` stays unchanged.

## Memorize first

1. `j foo bar` jumps to the highest-ranked directory matching both keywords,
   in order.
1. `jj foo` lists matches in fzf, for when the first match is wrong.
1. `fm foo` opens Yazi in the highest-ranked match for `foo`.
1. `C-x` in the sesh picker turns any ranked directory into a tmux session.
1. `zoxide edit` fixes rankings and removes stale entries.

## Matching rules

| Query           | Behavior                                                                    |
| --------------- | --------------------------------------------------------------------------- |
| `j gitlab`      | Top-ranked path containing `gitlab`                                         |
| `j gitlab ci`   | Keywords must appear in order; the last one matches the last path component |
| `j ~/Developer` | A real path works like `cd`                                                 |
| `j -`           | Returns to the previous directory                                           |

Ranking combines frequency and recency. Directories you visit often and
recently win ties.

## Commands

| Goal                                       | Command                |
| ------------------------------------------ | ---------------------- |
| Show candidates with their scores          | `zoxide query -ls foo` |
| Print the top match without jumping        | `zoxide query foo`     |
| Edit ranks or delete entries interactively | `zoxide edit`          |
| Remove a directory from the database       | `zoxide remove PATH`   |
| Seed a directory you haven't visited yet   | `zoxide add PATH`      |

`PATH` is a directory path.

## Integrations

| Where | Keys or command | Effect                               |
| ----- | --------------- | ------------------------------------ |
| Shell | `fm foo`        | Opens Yazi at the top match          |
| Yazi  | `Z`             | Jumps through zoxide inside Yazi     |
| sesh  | `C-x`           | Lists ranked directories as sessions |

## Recipes

**Jump into a deep worktree.** Type `j gitlab runner` instead of the full path.
If the result is wrong, run `jj gitlab runner` and pick from the list.

**Use a match in another command.** Run `nvim "$(zoxide query dotfiles)/README.md"`
to open a file without changing directories.
