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

    local logical_alias = augend.constant.new({
      elements = { "&&", "||" },
      word = false,
      cyclic = true,
    })

    local ordinal_numbers = augend.constant.new({
      -- elements through which we cycle. When we increment, we go down
      -- On decrement we go up
      elements = {
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
      -- if true, it only matches strings with word boundary. firstDate wouldn't work for example
      word = false,
      -- do we cycle back and forth (tenth to first on increment, first to tenth on decrement).
      -- Otherwise nothing will happen when there are no further values
      cyclic = true,
    })

    local weekdays = augend.constant.new({
      elements = {
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
      },
      word = true,
      cyclic = true,
    })

    local months = augend.constant.new({
      elements = {
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
      },
      word = true,
      cyclic = true,
    })

    local capitalized_boolean = augend.constant.new({
      elements = {
        "True",
        "False",
      },
      word = true,
      cyclic = true,
    })

    local order = augend.constant.new({
      elements = {
        "previous",
        "next",
      },
      word = true,
      cyclic = true,
    })

    local enable = augend.constant.new({
      elements = {
        "enable",
        "disable",
      },
      word = false,
      cyclic = true,
    })

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
        },
        vue = {
          augend.constant.new({ elements = { "let", "const" } }),
          augend.hexcolor.new({ case = "lower" }),
          augend.hexcolor.new({ case = "upper" }),
        },
        typescript = {
          augend.constant.new({ elements = { "let", "const" } }),
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
          augend.constant.new({
            elements = { "turn_off", "turn_on" },
            word = true,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "not_home", "home" },
            word = true,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "unavailable", "available" },
            word = true,
            cyclic = true,
          }),
        },
        markdown = {
          augend.constant.new({
            elements = { "[ ]", "[x]" },
            word = false,
            cyclic = true,
          }),
          augend.misc.alias.markdown_header,
        },
        json = {
          augend.semver.alias.semver, -- versioning (v1.1.2)
        },
        lua = {
          augend.constant.new({
            elements = { "and", "or" },
            word = true, -- if false, "sand" is incremented into "sor", "doctor" into "doctand", etc.
            cyclic = true, -- "or" is incremented into "and".
          }),
        },
        python = {
          augend.constant.new({
            elements = { "and", "or" },
          }),
        },
        ruby = {
          augend.constant.new({
            elements = { "be_allowed", "be_disallowed" },
            word = true,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "to", "not_to" },
            word = true,
            cyclic = true,
          }),
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
