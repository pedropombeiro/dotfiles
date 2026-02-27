# Justfile

[Just](https://github.com/casey/just) is a command runner used for project-specific tasks.

## File Location

Justfiles are typically located at the repository root with one of these names (in search order):

- `justfile`
- `.justfile`

Just searches from the current directory upward, using the first justfile it finds.

## Global Justfile

A global justfile at `~/.justfile` is used for dotfile management tasks.
When working in a repository with its own justfile, the local one takes precedence.
