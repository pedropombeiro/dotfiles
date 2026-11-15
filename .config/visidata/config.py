#!/usr/bin/env python

import datetime  # Allow additional datetime column formats
import json
import os
from pathlib import Path

import dateutil
from visidata import BaseSheet, DirSheet, GraphSheet, Sheet, colors, options, vd

################################################################################
# Shared VisiData layout with per-theme xterm-256 palettes.
theme_root = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "dotfiles"
theme_profile = json.loads((theme_root / "theme.json").read_text())
palette = json.loads(
    (theme_root / "themes" / theme_profile["name"] / "visidata.json").read_text()
)

# Plot colors for better visibility in graphs
PLOT_COLORS = {
    "c1": 2,    # green
    "c2": 1,    # red
    "c3": 6,    # cyan
    "c4": 3,    # yellow
    "c5": 7,    # white
    "c6": 201,
    "c7": 226,
    "c8": 51,
    "c9": 196,
    "c10": 46,
    "c11": 33,
    "c12": 207,
    "c13": 8,   # gray
    "c14": 19,
    "c15": 220,
    "c16": 88,
    "c17": 45,
    "c18": 22,
    "c19": 141,
    "c20": 118,
    "c21": 39,
    "c22": 208,
    "c23": 52,
    "c24": 156,
    "c25": 213,
    "c26": 224,
}

_plot_colors_str = " ".join(map(str, PLOT_COLORS.values()))

vd.themes[theme_profile["visidata"]] = dict(
    # Base colors
    color_default=f'{palette["fg1"]} on {palette["bg0"]}',
    color_default_hdr=f'bold {palette["bright_yellow"]} on {palette["bg0_s"]}',
    # Key column highlighting with good contrast
    color_key_col=f'{palette["bright_green"]} on {palette["bg0"]}',
    # Current column/row (cursor position)
    color_current_row=f'bold {palette["bg0"]} on {palette["blue"]}',  # Inverted for visibility
    color_current_col=f'{palette["bright_blue"]} on {palette["bg0_s"]}',
    color_current_cell=f'bold {palette["bg0"]} on {palette["bright_blue"]}',
    # Selected rows - high contrast for readability
    color_selected_row=f'{palette["bg0"]} on {palette["bright_green"]}',  # Inverted green background
    # Column separators
    color_column_sep=f'{palette["bg2"]} on {palette["bg0"]}',
    # Aggregator
    color_aggregator=f'bold {palette["fg0"]} on {palette["bg0_h"]}',
    # Status bars and messages
    color_status=f'{palette["fg1"]} on {palette["bg0_h"]}',
    color_active_status=f'{palette["fg2"]} on {palette["bg0_s"]}',
    color_error=f'bold {palette["bright_red"]} on {palette["bg0_h"]}',
    color_warning=f'{palette["bright_yellow"]} on {palette["bg0_h"]}',
    # Sidebar
    color_sidebar=f'{palette["fg0"]} on {palette["bg2"]}',
    color_sidebar_title=f'{palette["bright_orange"]} on {palette["bg2"]}',
    color_longname_guide=f'{palette["fg4"]} on {palette["bg2"]}',
    color_heading=f'{palette["bright_orange"]} on {palette["bg2"]}',
    # Cell content types
    color_note_row=f'{palette["bright_blue"]} on {palette["bg0"]}',
    # Graph colors
    color_graph_hidden=f'{palette["blue"]}',
    plot_colors=_plot_colors_str,
    # Bottom sheet colors
    color_bottom_hdr=f'bold {palette["bright_yellow"]} on {palette["bg0_h"]}',
    # Command palette and menus
    color_cmdpalette=f'{palette["fg1"]} on {palette["bg3"]}',
    color_menu=f'{palette["fg1"]} on {palette["bg3"]}',
    color_menu_active=f'bold {palette["bright_yellow"]} on {palette["bg0_s"]}',
    color_menu_help=f'italic {palette["bg0_h"]} on {palette["blue"]}',
    # Hidden columns
    color_hidden_col=f'{palette["gray"]} on {palette["bg0"]}',
    # Add-on status colors
    color_add_pending=f'{palette["bright_yellow"]} on {palette["bg0"]}',
    color_change_pending=f'{palette["bright_purple"]} on {palette["bg0"]}',
    color_delete_pending=f'{palette["bright_red"]} on {palette["bg0"]}',
    disp_status_fmt="{sheet.sheetlist} ",
    disp_rstatus_fmt="{sheet.threadStatus} {sheet.keystrokeStatus}   {sheet.longname}[/]   {sheet.nRows} {sheet.rowtype} {sheet.modifiedStatus}{sheet.selectedStatus}{vd.replayStatus} [:longname_status]{sheet.cursorRowIndex1}:{sheet.cursorVisibleColIndex1} {sheet.vertPos}[/] {vd.sidebarStatus}",
)

if options.theme == "":
    options.theme = theme_profile["visidata"]

################################################################################
# Set some UI preferences for better experience

options.motd_url = ""
vd.motd = ""

# Make @ use datetime instead of time
Sheet.addCommand(
    "@",
    "type-datetime",
    'cursorCol.type=date; cursorCol.fmtstr="%Y-%m-%d %H:%M:%S"',
    "set type of current column to datetime",
)


@Sheet.after
def afterLoad(_sheet):
    options.numeric_binning = True
    options.disp_date_fmt = "%Y-%m-%d"
    options.disp_menu_boxchars = "││──╭╮╰╯├┤"


################################################################################
# Statusline variables


@Sheet.property
def cursorRowIndex1(sheet):
    return sheet.cursorRowIndex + 1


@Sheet.property
def cursorVisibleColIndex1(sheet):
    return sheet.cursorVisibleColIndex + 1


@Sheet.property
def vertPos(sheet):
    if sheet.cursorRowIndex == 0:
        return str(1) + "%"
    return str(int((sheet.cursorRowIndex + 1) * 100 / sheet.nRows)) + "%"


################################################################################
# Key bindings

# Optional: Custom keybindings can be added here
# Example: bindkey('Alt+q', 'quit-sheet')


################################################################################
# Aggregators


def agg_range(values):
    # Filter out invalid or incompatible values
    valid = []
    for v in values:
        if v is None:
            continue
            # ignore arrays like [1] value
            if isinstance(v, (list, tuple, dict)):
                continue
            valid.append(v)

    if not valid:
        return None

    try:
        diff = max(valid) - min(valid)
        return diff
    except Exception:
        return None


def agg_non_empty(values):
    return sum(1 for v in values if v is not None and v != "")


vd.aggregator("range", agg_range, "returns (max - min)", type=float)
vd.aggregator("non_empty", agg_non_empty, "returns non empty values")


@BaseSheet.api
def apply_aggregator_to_all_columns(sheet: BaseSheet) -> None:
    agg = vd.input("Aggregator: ")
    if agg:
        sheet.addAggregators(
            [col for col in sheet.visibleCols if vd.isNumeric(col)], [agg]
        )


BaseSheet.addCommand(
    "g+",
    "add-aggregator-to-all-columns",
    "apply_aggregator_to_all_columns()",
    "add aggregator to all visible columns (prompt for name)",
)


################################################################################
# autotune.py
# https://gist.github.com/cool-RR/47d8ebb7afc636a995fccf889aada8e9

N_ROWS_FOR_TYPE_GUESSING = 100
DEFAULT_FLOAT_PRECISION = 5
DATE_FORMATS = [
    "%Y-%m-%dT%H:%M:%S.%f%z",
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S.%f",
    "%Y-%m-%d %H:%M:%S.%f",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d",
]


@GraphSheet.api
def guess_y_axis(graph_sheet: GraphSheet) -> None:
    values = tuple(
        column.getTypedValue(row)
        for column in graph_sheet.ycols
        for row in column.sheet.rows
    )
    min_value = min(values)
    max_value = max(values)
    if 0 <= min_value <= max_value <= 1:
        graph_sheet.set_y("-0.1 1.1")
        graph_sheet.extra_y_ticks = (0, 1)
    elif -1 <= min_value <= max_value <= 1:
        graph_sheet.set_y("-1.1 1.1")
        graph_sheet.extra_y_ticks = (-1, 1)


def guess_column_types(sheet: BaseSheet) -> None:
    if isinstance(sheet, DirSheet):
        # These break for some reason.
        return

    for column in sheet.visibleCols:
        if column.type not in (anytype, int):
            continue

        type_candidates = [int, float, date, anytype]
        try:
            values = tuple(
                column.getValue(r) for r in sheet.rows[:N_ROWS_FOR_TYPE_GUESSING]
            )
        except Exception:
            # I got an inexplicable `NameError` here while doing this on a `DirSheet`, so let's not
            # guess a column when that happens.
            continue

        for value in values:
            if value is None or value == "":
                continue

            if date in type_candidates:
                if value is int or value is float:
                    type_candidates.remove(date)
                else:
                    found = False
                    for datefmt in DATE_FORMATS:
                        try:
                            datetime.datetime.strptime(value, datefmt)
                            column.fmtstr = datefmt
                            found = True
                            break
                        except TypeError:
                            pass
                        except ValueError:
                            pass
                    if not found:
                        try:
                            date(value)
                        except dateutil.parser.ParserError:
                            type_candidates.remove(date)

            if int in type_candidates:
                try:
                    value_as_int = int(value)
                except (ValueError, TypeError):
                    type_candidates.remove(int)
                else:
                    if float(value) != value_as_int:
                        type_candidates.remove(int)

            if float in type_candidates:
                try:
                    float(value)
                except (ValueError, TypeError):
                    type_candidates.remove(float)

        column.type = type_candidates[0]

        if column.type is float:
            numbers = tuple(
                column.getTypedValue(r) for r in sheet.rows[:N_ROWS_FOR_TYPE_GUESSING]
            )
            biggest_number = max(map(abs, numbers))
            if biggest_number > 0:
                for i in range(2, 6):
                    if 10 ** (-(i - 1)) < biggest_number:
                        if i != DEFAULT_FLOAT_PRECISION:
                            column.fmtstr = f"%.{i}f"
                        break


def guess_key_columns(sheet: BaseSheet) -> None:
    if sheet.columns and sheet.columns[0].name in (
        "generation",
        "i_agent",
        "time_step",
    ):
        sheet.setKeys([sheet.columns[0]])


@BaseSheet.api
def autotune(sheet: BaseSheet) -> None:
    if isinstance(sheet, GraphSheet):
        guess_y_axis(sheet)
        # Put selection box outside the plot:
        sheet.cursorBox.xmin = sheet.visibleBox.xmin - 8 * sheet.cursorBox.w
    else:
        visidata.features.expand_cols.expand_cols_deep(
            sheet, sheet.visibleCols, depth=0
        )

        guess_column_types(sheet)
        guess_key_columns(sheet)


@BaseSheet.api
def autowidth(sheet: BaseSheet) -> None:
    for column in sheet.visibleCols:
        column: Column
        if column.type is anytype:
            try:
                first_value = column.getValue(sheet.rows[0])
            except Exception:
                # I got an inexplicable `NameError` here while doing this on a `DirSheet`,
                # so let's not guess a column when that happens.
                continue
            if isinstance(first_value, dict):
                column.setWidth(len(column.name) + 5)
                continue
        column.setWidth(column.getMaxWidth(sheet.visibleRows))


BaseSheet.addCommand("b", "autotune", "autotune()")
BaseSheet.addCommand("Alt+=", "autowidth", "autowidth()")
