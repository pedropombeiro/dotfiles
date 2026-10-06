# jless cheat sheet

This setup uses upstream bindings without a tracked jless configuration.
Open JSON with `jless FILE`, or pipe it with `COMMAND | jless`. `FILE` is
the input path, and `COMMAND` produces JSON. Newline-delimited JSON works
too. For YAML, use `jless FILE.yaml` or `COMMAND | jless --yaml`.

LazyDocker's custom **Inspect container** and **Inspect image** commands open
`docker inspect` output in jless. Open this sheet with `cheat jless`.

## Memorize first

1. `J` and `K` move between siblings, skipping their nested contents.
1. `H` moves to the parent without collapsing the current node.
1. `c` collapses siblings one level. `C` collapses them recursively.
1. `*` finds the next occurrence of the current key, even inside collapsed data.
1. `y p` copies an exact path. `y q` copies a jq path with array wildcards.

## Structural navigation

| Goal | Keys | Notes |
| --- | --- | --- |
| Move between sibling entries | `J` or `K` | Prefix with a count, such as `5 J` |
| Move to the parent | `H` | Keeps the current subtree expanded |
| Collapse a container, or move to its parent | `h` | Collapses first if the current container is expanded |
| Expand a container, or enter its first child | `l` | Expands first if the current container is collapsed |
| Toggle the current container | `Space` | |
| Collapse or expand siblings one level | `c` or `e` | Includes the current node |
| Collapse or expand siblings recursively | `C` or `E` | Useful for a whole array of records |
| Jump to the first or last sibling | `0` or `$` | `^` also selects the first |
| Move to the next or previous change in depth | `w` or `b` | Skips entries at the same depth |
| Jump to a line and expand its ancestors | `42 G` | Uses pretty-printed line numbers, not original input lines |
| Center the focused node | `z z` | `z t` puts it at the top |

## Search and display

| Goal | Keys | Notes |
| --- | --- | --- |
| Search forward or backward | `/` or `?` | Searches collapsed content too |
| Repeat the search or reverse its direction | `n` or `N` | Relative to the original search direction |
| Find the same key in another record | `*` or `#` | Next or previous occurrence |
| Switch between data and JSON line modes | `m` | Line mode includes quotes, commas, and closing delimiters |
| Jump to a matching delimiter in line mode | `%` | Focus an opening or closing array/object delimiter |
| Scroll a truncated value horizontally | `.` or `,` | Add a count to move several characters |
| Show the end or start of a truncated value | `;` | Toggles between the two |
| Reduce or increase indentation | `<` or `>` | Useful for deeply nested data |
| Toggle relative line numbers | `:set relativenumber!` | Helps with counted movements |
| Open help | `F1` or `:help` | `q` exits jless |

Search uses smart case: lowercase patterns ignore case, and patterns with
uppercase letters match case. Append `/s` to force a case-sensitive search,
such as `/status/s`.

Unlike most regex tools, jless treats `[]` and `{}` as literal characters.
Escape them to use character classes or repetition counts: `/\[bch\]at`
matches `bat`, `cat`, or `hat`. Search uses normalized JSON with quoted keys,
even when data mode hides those quotes.

## Copy values and paths

| Goal | Keys | Notes |
| --- | --- | --- |
| Copy a pretty-printed value or subtree | `y y` | Includes nested objects and arrays |
| Copy a value on one line | `y v` | |
| Copy a string's unescaped contents | `y s` | Use this instead of copying JSON string quotes |
| Copy the current key | `y k` | |
| Copy an exact path | `y p` | For example, `.items[3].status` |
| Copy a bracket-only path | `y b` | For example, `["items"][3]["status"]` |
| Copy a jq path for equivalent entries | `y q` | For example, `.items[].status` |
| Print a value for terminal selection | `p p` or `p s` | Pretty-printed subtree or unescaped string |

Printing temporarily disables mouse tracking so you can select text with the
terminal. Most copy commands have matching `p` commands, but printing an exact
path uses `p P`, not `p p`.

## Recipes

**Compare the same field across records.** Navigate to the field, then press
`*` repeatedly. Use `H` to inspect each containing record without collapsing
the field's contents.

**Turn exploration into a jq query.** Find the value you need and press `y q`.
Paste the path into `jq 'PATH' FILE`, replacing `PATH` with the copied filter
and `FILE` with the input path. Use `y p` instead when you want one exact array
element.

**Read a long error message.** Focus the string and press `p s` to print its
unescaped contents. For a quick look without printing, use `;` to jump to the
end and back.

Checked on 2026-10-06 against jless 0.9.0 and the
[upstream user guide](https://jless.io/user-guide.html).
