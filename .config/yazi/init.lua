-- Show symlink in status bar
Status:children_add(function(self)
  local h = self._current.hovered
  if h and h.link_to then
    return " -> " .. tostring(h.link_to)
  else
    return ""
  end
end, 3300, Status.LEFT)

-- Show user/group of files in status bar
Status:children_add(function()
  local h = cx.active.current.hovered
  if h == nil or ya.target_family() ~= "unix" then
    return ""
  end

  return ui.Line({
    " ",
    ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
    ":",
    ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
    " ",
  })
end, 500, Status.RIGHT)

-- https://github.com/dedukun/relative-motions.yazi
require("relative-motions"):setup({ show_numbers = "relative", show_motion = true, enter_mode = "first" })

-- https://github.com/dedukun/bookmarks.yazi
require("bookmarks"):setup({
  last_directory = { enable = true, persist = true, mode = "dir" },
  persist = "vim",
  desc_format = "full",
  file_pick_mode = "hover",
  custom_desc_input = false,
  notify = {
    enable = true,
    timeout = 1,
    message = {
      new = "New bookmark '<key>' -> '<folder>'",
      delete = "Deleted bookmark in '<key>'",
      delete_all = "Deleted all bookmarks",
    },
  },
})

-- https://yazi-rs.github.io/docs/dds#session.lua
require("session"):setup({
  sync_yanked = true,
})

-- https://yazi-rs.github.io/docs/tips#folder-rules
require("folder-rules"):setup()

-- https://github.com/yazi-rs/plugins/tree/main/git.yazi
th.git = th.git or {}
th.git.added_sign = ""
th.git.modified_sign = ""
th.git.deleted_sign = ""
require("git"):setup()

local gruvbox_theme = require("yatline-gruvbox"):setup("dark") -- or "light"
-- Use colors from light theme, because the default background of section_a is too light
gruvbox_theme.branch_color = "#076678"
gruvbox_theme.commit_color = "#8f3f71"
gruvbox_theme.behind_color = "#af3a03"
gruvbox_theme.ahead_color = "#427b58"
gruvbox_theme.stashes_color = "#8f3f71"
gruvbox_theme.state_color = "#9d0006"
gruvbox_theme.unstaged_color = "#af3a03"
gruvbox_theme.untracked_color = "#427b58"

require("yatline"):setup({
  theme = gruvbox_theme,
  show_background = false,

  header_line = {
    left = {
      section_a = {
        { type = "coloreds", custom = false, name = "tab_path" },
        { type = "coloreds", custom = false, name = "githead" },
      },
      section_b = {},
      section_c = {},
    },
    right = {
      section_a = {},
      section_b = {},
      section_c = {},
    },
  },

  status_line = {
    left = {
      section_a = {
        { type = "string", custom = false, name = "tab_mode" },
      },
      section_b = {
        { type = "string", custom = false, name = "hovered_size" },
      },
      section_c = {
        { type = "string", custom = false, name = "hovered_path" },
        { type = "coloreds", custom = false, name = "count" },
      },
    },
    right = {
      section_a = {
        { type = "string", custom = false, name = "cursor_position" },
      },
      section_b = {
        { type = "string", custom = false, name = "cursor_percentage" },
      },
      section_c = {
        { type = "string", custom = false, name = "hovered_mime", params = { true } },
        { type = "coloreds", custom = false, name = "permissions" },
        { type = "coloreds", custom = false, name = "modified_time" },
      },
    },
  },
})

require("yatline-modified-time"):setup()

-- TEMPORARY FIX: Override yatline-modified-time to handle empty directories
-- Remove this once https://github.com/wekauwau/yatline-modified-time.yazi/pull/4 is merged
if Yatline then
  function Yatline.coloreds.get:modified_time()
    local h = cx.active.current.hovered
    local modified_time = {}
    local time = ""

    if h and h.cha and h.cha.mtime then
      time = " M: " .. os.date("%Y-%m-%d %H:%M", h.cha.mtime // 1) .. " "
    end

    table.insert(modified_time, { time, "silver" })
    return modified_time
  end
end

require("yatline-githead"):setup({
  show_branch = true,
  branch_prefix = "",
  branch_color = gruvbox_theme.branch_color,
  branch_symbol = "",
  branch_borders = "",

  commit_color = gruvbox_theme.commit_color,
  commit_symbol = "",

  show_behind_ahead = true,
  behind_color = gruvbox_theme.behind_color,
  behind_symbol = " ",
  ahead_color = gruvbox_theme.ahead_color,
  ahead_symbol = " ",

  show_stashes = true,
  stashes_color = gruvbox_theme.stashes_color,
  stashes_symbol = " ",

  show_state = true,
  show_state_prefix = true,
  state_color = gruvbox_theme.state_color,
  state_symbol = "~",

  show_staged = true,
  staged_color = gruvbox_theme.staged_color,
  staged_symbol = " ",

  show_unstaged = true,
  unstaged_color = gruvbox_theme.unstaged_color,
  unstaged_symbol = " ",

  show_untracked = true,
  untracked_color = gruvbox_theme.untracked_color,
  untracked_symbol = " ",
})

require("yatline-tab-path"):setup({
  theme = gruvbox_theme,
  path_fg = "cyan",
  filter_fg = "brightyellow",
  search_label = " search",
  filter_label = " filter",
  no_filter_label = "",
  flatten_label = " flatten",
  separator = "  ",
})
