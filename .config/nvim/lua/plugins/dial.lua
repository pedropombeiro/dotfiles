-- dial.nvim (https://github.com/monaqa/dial.nvim)
--  enhanced increment/decrement plugin for Neovim.

local function _dial(increment, g)
  local mode = vim.fn.mode(true)
  -- Use visual commands for VISUAL 'v', VISUAL LINE 'V' and VISUAL BLOCK '\22'
  local is_visual = mode == "v" or mode == "V" or mode == "\22"
  local func = (increment and "inc" or "dec") .. (g and "_g" or "_") .. (is_visual and "visual" or "normal")
  local group = vim.g.dials_by_ft[vim.bo.filetype] or "default"
  return require("dial.map")[func](group)
end

return {
  "monaqa/dial.nvim",
  event = { "BufNewFile", "BufReadPost" },
  keys = {
    { "<C-a>", function() return _dial(true) end, expr = true, desc = "Increment", mode = { "n", "v" } },
    { "<C-x>", function() return _dial(false) end, expr = true, desc = "Decrement", mode = { "n", "v" } },
    { "g<C-a>", function() return _dial(true, true) end, expr = true, desc = "Increment", mode = { "n", "v" } },
    { "g<C-x>", function() return _dial(false, true) end, expr = true, desc = "Decrement", mode = { "n", "v" } },
  },
  opts = function()
    local augend = require("dial.augend")
    local make_const = function(elements, word)
      return augend.constant.new({
        elements = elements,
        word = word or true,
        cyclic = true,
      })
    end

    local logical_alias = make_const({ "&&", "||" }, false)
    local ordinal_numbers = make_const(
      {
        "first",
        "second",
        "third",
        "fourth",
        "fifth",
        "sixth",
        "seventh",
        "eighth",
        "ninth",
        "tenth",
        "last",
      },
      false -- if true, it only matches strings with word boundary. firstDate wouldn't work for example
    )

    local weekdays = make_const({
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    })

    local months = make_const({
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    })

    local capitalized_boolean = make_const({ "True", "False" })
    local order = make_const({ "previous", "next" })
    local enable = make_const({ "enable", "disable" }, false)

    return {
      dials_by_ft = {
        css = "css",
        vue = "vue",
        javascript = "typescript",
        typescript = "typescript",
        typescriptreact = "typescript",
        javascriptreact = "typescript",
        json = "json",
        lua = "lua",
        markdown = "markdown",
        sass = "css",
        scss = "css",
        python = "python",
        ruby = "ruby",
        ["yaml.homeassistant"] = "homeassistant",
      },
      groups = {
        default = {
          augend.integer.alias.decimal, -- nonnegative decimal number (0, 1, 2, 3, ...)
          augend.integer.alias.decimal_int, -- nonnegative and negative decimal number
          augend.integer.alias.hex, -- nonnegative hex number  (0x01, 0x1a1f, etc.)
          augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
          ordinal_numbers,
          weekdays,
          months,
          capitalized_boolean,
          augend.constant.alias.bool, -- boolean value (true <-> false)
          logical_alias,
          enable,
          order,
          make_const({ "✅", "❌" }),
          make_const({ "show", "hide" }),
          make_const({ "active", "inactive" }),
          make_const({ "Active", "Inactive" }),
          make_const({ "On", "Off" }),
          make_const({ "on", "off" }),
          make_const({ "Yes", "No" }),
          make_const({ "yes", "no" }),
        },
        vue = {
          make_const({ "let", "const" }),
          augend.hexcolor.new({ case = "lower" }),
          augend.hexcolor.new({ case = "upper" }),
        },
        typescript = {
          make_const({ "let", "const" }),
        },
        css = {
          augend.hexcolor.new({
            case = "lower",
          }),
          augend.hexcolor.new({
            case = "upper",
          }),
        },
        homeassistant = {
          make_const({ "turn_off", "turn_on" }),
          make_const({ "not_home", "home" }),
          make_const({ "unavailable", "available" }),
        },
        markdown = {
          make_const({ "[ ]", "[x]" }, false),
          augend.misc.alias.markdown_header,
        },
        json = {
          augend.semver.alias.semver, -- versioning (v1.1.2)
        },
        lua = {
          make_const({ "and", "or" }),
        },
        python = {
          make_const({ "and", "or" }),
        },
        ruby = {
          make_const({ "be_allowed", "be_disallowed" }),
          make_const({ "to", "not_to" }),
        },
      },
    }
  end,
  config = function(_, opts)
    -- copy defaults to each group
    for name, group in pairs(opts.groups) do
      if name ~= "default" then vim.list_extend(group, opts.groups.default) end
    end
    require("dial.config").augends:register_group(opts.groups)
    vim.g.dials_by_ft = opts.dials_by_ft
  end,
}
