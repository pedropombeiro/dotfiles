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
gruvbox_theme.branch_color = "#ebdbb2"
gruvbox_theme.commit_color = "#d3869b"
gruvbox_theme.behind_color = "#af3a03"
gruvbox_theme.ahead_color = "#427b58"
gruvbox_theme.stashes_color = "#d3869b"
gruvbox_theme.state_color = "#cc241d"
gruvbox_theme.unstaged_color = "#af3a03"
gruvbox_theme.untracked_color = "#427b58"

require("yatline"):setup({
  theme = gruvbox_theme,
  show_background = true,
  display_header_line = false,
  display_status_line = true,

  section_separator = { open = " ", close = " " },
  part_separator = { open = "  ", close = "  " },
  inverse_separator = { open = "", close = "" },

  status_line = {
    left = {
      section_a = {
        { type = "string", custom = false, name = "tab_mode" },
      },
      section_b = {
        { type = "coloreds", custom = false, name = "githead" },
        { type = "coloreds", custom = false, name = "count" },
        { type = "string", custom = false, name = "hovered_size" },
      },
      section_c = {
        { type = "coloreds", custom = false, name = "hovered_path_icon" },
        { type = "string", custom = false, name = "search_query", params = { " search:" } },
        { type = "string", custom = false, name = "filter_query", params = { " filter:" } },
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

-- Coloreds variant of `hovered_path` that prefixes the file icon in the icon's own
-- theme colour. This has to be `coloreds` rather than `string` so the icon and the
-- path can carry different colours.
--
-- `Icon.style` is userdata whose `fg` is a getter *method*, not a value: passing
-- `icon.style.fg` to `Span:fg()` fails with "expected a Color". Call
-- `icon.style:fg()` to get the `Color` that `Span:fg()` accepts.
function Yatline.coloreds.get:hovered_path_icon()
  local h = cx.active.current.hovered
  if not h then
    return ""
  end

  -- In a search/flatten view the URL carries the `search://` scheme, which
  -- `ya.readable_path` does not strip; use the plain path instead.
  local url = h.url
  local path = ya.readable_path(tostring(url.spec.is_search and url.path or url))
  local path_fg = "#a89984" -- Match Lualine section_c fg (gray)

  -- `th.icon:match()` returns `Icon?`, so guard against no matching [icon] rule
  local icon = th.icon:match(h)
  if not icon then
    return { { path, path_fg } }
  end

  local ok, icon_fg = pcall(function()
    return icon.style:fg()
  end)

  return {
    { icon.text .. " ", (ok and icon_fg) or path_fg },
    { path, path_fg },
  }
end

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

-- TEMPORARY FIX: upstream yatline still uses two APIs deprecated in yazi 26.8,
-- which warn on every status-line redraw. Remove each once fixed upstream:
--   `File:icon()`   -> `th.icon:match(file)`   https://github.com/imsi32/yatline.yazi/issues/79
--   `Url.is_search` -> `Url.spec.is_search`    (unreported)
if Yatline then
  -- `hovered_file_extension` is not in the status line above, but override it so the
  -- deprecation cannot resurface if it is ever added back.
  function Yatline.string.get:hovered_file_extension(show_icon)
    local hovered = cx.active.current.hovered
    if not hovered then
      return ""
    end

    local name = hovered.cha.is_dir and "dir" or (tostring(hovered.url.ext or "null"))

    if not show_icon then
      return name
    end

    local icon = th.icon:match(hovered)
    return icon and (icon.text .. " " .. name) or name
  end

  local function is_search(url)
    return url.spec.is_search
  end

  function Yatline.string.get:search_query(key)
    key = key or "search:"

    local cwd = cx.active.current.cwd
    if is_search(cwd) then
      return string.format("%s %s", key, cwd.spec.domain)
    end

    return ""
  end

  -- Verbatim copy of upstream `count` with `cwd.is_search` -> `cwd.spec.is_search`.
  -- Reads icons/colours from `Yatline.config`, so it needs no theme duplication.
  function Yatline.coloreds.get:count(filter, zero_check)
    filter = filter or false
    zero_check = zero_check or false

    local num_yanked = #cx.yanked
    local num_selected = #cx.active.selected
    local num_files = #cx.active.current.files

    local coloreds = {}

    if filter then
      local files_count = (cx.active.current.files.filter or is_search(cx.active.current.cwd))
          and Yatline.config.filtereds
        or Yatline.config.files

      if (zero_check and num_files > 0) or not zero_check then
        table.insert(coloreds, { string.format("%s %d", files_count.icon, num_files), files_count.fg })
      end
    end

    if (zero_check and num_selected > 0) or not zero_check then
      if #coloreds > 0 then
        table.insert(coloreds, { " ", Yatline.config.selected.fg })
      end
      table.insert(
        coloreds,
        { string.format("%s %d", Yatline.config.selected.icon, num_selected), Yatline.config.selected.fg }
      )
    end

    if (zero_check and num_yanked > 0) or not zero_check then
      local yanked = cx.yanked.is_cut and Yatline.config.cut or Yatline.config.copied

      if #coloreds > 0 then
        table.insert(coloreds, { " ", yanked.fg })
      end
      table.insert(coloreds, { string.format("%s %d", yanked.icon, num_yanked), yanked.fg })
    end

    return coloreds
  end
end
