# VisiData cheat sheet

Configuration: [`~/.config/visidata/config.py`](../../.config/visidata/config.py). Open a file with
`vd FILE`, or pipe CSV data with `COMMAND | vd -f csv`. `FILE` is the input
path, and `COMMAND` produces CSV. Open this sheet with `cheat vd` or
`cheat --local vd`.

## Memorize first

1. `F` groups the current column into a frequency table. `Enter` opens a
   group's source rows.
1. `,` selects rows matching the current cell. `"` opens the selected subset.
1. `+` adds an aggregator such as `sum`, and `g +` adds one to every visible
   numeric column in this setup.
1. `!` marks key columns for grouping, joining, and plotting.
1. `Space` runs a command by name. `z C-h` lists the current sheet's commands.

## How this setup behaves

- `b` runs the custom autotune command instead of toggling the sidebar. It
  expands nested columns, then guesses types from the first 100 rows. Check
  the result if later rows have different formats.
- `M-=` fits visible columns to the rows on screen. Dictionary columns that
  still have the default type use the column name's width plus padding.
- `@` sets datetime type and displays `%Y-%m-%d %H:%M:%S`.
- Numeric frequency tables use range bins. For exact numeric groups, press
  `Space`, run `options-sheet`, and set `numeric_binning` to `False` before
  creating the frequency table.
- The custom `non_empty` aggregator counts values other than `None` and `""`.

## Search and row subsets

| Goal | Keys | Notes |
| --- | --- | --- |
| Search the current column | `/` or `?` | Forward or backward regex search |
| Search every visible column | `g /` | `n` and `N` repeat the search |
| Toggle the current row and advance | `t` | `s` selects; `u` unselects |
| Select rows matching the current cell | `,` | Compares displayed values. `z ,` compares typed values |
| Select rows by regex | `\|` or `g \|` | Current column or every visible column |
| Select rows by Python expression | `z \|` | For example, `amount > 100 and status == 'failed'` |
| Select all, clear, or invert | `g s`, `g u`, `g t` | Selection is additive until you clear it |
| Open only selected rows | `"` | Shares row objects with the source; edits can affect it |
| Open an independent copy of selected rows | `z "` | Deep copy for editing without changing source rows |
| Sort the current column | `[` or `]` | Ascending or descending, using the column type |

## Columns and nested data

| Goal | Keys | Notes |
| --- | --- | --- |
| Set string, integer, float, or datetime type | `~`, `#`, `%`, `@` | Assign types before sorting or calculating |
| Toggle a key column | `!` | Repeat on multiple columns for a composite key |
| Rename the current column | `^` | Use Python-friendly names for expressions |
| Hide the current column | `-` | In `C`, set its `width` above zero to restore it |
| Fit the current column or all visible columns | `_` or `g _` | Repeating resets widths to defaults |
| Fit columns to the rows on screen | `M-=` | Custom binding |
| Edit column names, types, widths, or aggregators | `C` | Opens the Columns sheet |
| Expand containers one level | `(` or `g (` | Current column or all visible columns |
| Expand a column to a chosen depth | `z (` | Enter `0` to expand fully |
| Collapse expanded sibling columns | `)` | Restores their parent column |
| Inspect the current cell as a Python object | `z C-y` | Useful for nested JSON |
| Add a calculated column | `=` | Python expression, such as `quantity * unit_price` |
| Set a column from an expression | `g =` | Selected rows, or all rows if none are selected |

## Aggregations, pivots, and joins

| Goal | Keys | Notes |
| --- | --- | --- |
| Add an aggregator to the current column | `+` | Choose `sum`, `mean`, `min`, `max`, or `non_empty` |
| Add an aggregator to visible numeric columns | `g +` | Custom binding. Prompts for the aggregator name |
| Group by the current column | `F` | Includes aggregators assigned to other columns |
| Group by all key columns | `g F` | Mark grouping columns with `!` first |
| Summarize all rows and selected rows | `z F` | Uses the assigned aggregators |
| Inspect source rows behind a group | `Enter` | In a frequency table; `g Enter` opens selected groups |
| Build a pivot table | `W` | Key columns define rows. Current column defines pivot values |
| Join sheets | `S`, select sheets with `t`, then `&` | Set matching key columns on each sheet first, then choose the join type |
| Plot the current numeric column | `.` | Numeric key column supplies the x-axis. Categorical keys supply colors |
| Plot all visible non-key numeric columns | `g .` | Hide unrelated numeric columns first |

For a pivot, assign aggregators to the measure columns before pressing `W`.
For example, mark `region` as a key, add `sum` to `revenue`, then move to
`month` and press `W`.

## Sheets, undo, and export

| Goal | Keys | Notes |
| --- | --- | --- |
| Open another file or URL | `o` | Adds another sheet to the session |
| Switch to an active sheet | `S`, then `Enter` | `g S` includes previously closed sheets |
| Return from a result sheet | `q` | Closes the current sheet |
| Reopen the most recently closed sheet | `g U` | |
| Undo or redo a change | `U` or `R` | Not every operation is undoable |
| View the latest error traceback | `C-e` | Useful for type and expression errors |
| Save the current sheet | `C-s` | Extension chooses format, such as `.csv` or `.json` |
| Save the command log | `C-d` | Use `.vdj`. Replay later with `vd -p FILE.vdj` |

`C-s` exports the current sheet, not just its selected rows. Open a subset with
`"` first, and save to a new path to preserve the original file. Hidden columns
do not appear in CSV export. Commands and expressions in a replay log can
execute code, so replay only logs you trust.

## Recipes

**Summarize revenue by category.** Open the CSV, move to `revenue`, press `%`,
and add `sum` with `+`. Move to `category` and press `F`. Sort the sum column
with `]`, then press `Enter` on a category to inspect its records.

**Export failed records.** Move to `status`, clear old selections with `g u`,
and select failures with `\|` and the regex `^failed$`. Press `"`, then `C-s`,
and save as `failed.csv`.

**Investigate nested JSON.** Open the JSON file, move to a container column,
and press `(` to expand one level, or `z (` and enter `0` to expand fully.
Use `z C-y` to inspect a cell, then `q` to return. Set numeric types with `#`
or `%` before adding expressions or aggregators.

Last verified on 2026-10-06 against VisiData 3.4 and the tracked configuration.
