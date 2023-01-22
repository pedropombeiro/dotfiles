-- Neotest (https://github.com/nvim-neotest/neotest)
--  An extensible framework for interacting with tests within NeoVim.

---@format disable-next
local keys = {
  { "<leader>rt", function() require("neotest").run.run() end,                     desc = "Run the nearest test" },
  { "<leader>rd", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug the nearest test" },
  { "<leader>rT", function() require("neotest").run.run(vim.fn.expand("%")) end,   desc = "Run the current file" },
  { "<leader>rr", function() require("neotest").summary.open() end,                desc = "Open test summary" },
}

return {
  "nvim-neotest/neotest",
  ft = { "go", "ruby" },
  keys = keys,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",

    "nvim-neotest/neotest-go",
    {
      "olimorris/neotest-rspec",
      keys = {
        {
          "<leader>rb",
          ":Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')<CR>",
          desc = "Run MR tests",
        }
      }
    }
  },
  init = function()
    -- Keymaps
    local m = require("mapx")
    m.nname("<leader>r", "Test")
  end,
  config = function()
    -- get neotest namespace (api call creates or returns namespace)
    local neotest_ns = vim.api.nvim_create_namespace("neotest")
    vim.diagnostic.config({
      virtual_text = {
        format = function(diagnostic)
          local message = diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
          return message
        end,
      },
    }, neotest_ns)

    local neotest = require("neotest")
    neotest.setup({
      adapters = {
        require("neotest-go") {
          experimental = {
            test_table = true,
          },
          args = { "-count=1", "-timeout=60s" }
        },
        require("neotest-rspec")({
          rspec_cmd = function()
            return vim.tbl_flatten({
              "bundle",
              "exec",
              "rspec",
            })
          end
        }),
      },
      icons = {
        expanded           = "",
        child_prefix       = "",
        child_indent       = "",
        final_child_prefix = "",
        non_collapsible    = "",
        collapsed          = "",

        passed  = "",
        running = "",
        failed  = "",
        unknown = ""
      },
    })

    -- Theming (from https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/config/init.lua)
    local function set_hl(name, attr)
      vim.api.nvim_set_hl(0, name, attr)
    end

    ---@format disable-next
    local function define_gruvbox_highlights()
      set_hl("NeotestPassed",       { ctermfg = "Green",   fg = "#b8bb26" })
      set_hl("NeotestFailed",       { ctermfg = "Red",     fg = "#fb4934" })
      set_hl("NeotestRunning",      { ctermfg = "Yellow",  fg = "#fabd2f" })
      set_hl("NeotestSkipped",      { ctermfg = "Cyan",    fg = "#83a598" })
      set_hl("NeotestTest",         { link    = "Normal" })
      set_hl("NeotestNamespace",    { ctermfg = "Magenta", fg = "#d3869b" })
      set_hl("NeotestFocused",      { bold    = true, underline = true })
      set_hl("NeotestFile",         { ctermfg = "Cyan",    fg = "#83a598" })
      set_hl("NeotestDir",          { ctermfg = "Cyan",    fg = "#83a598" })
      set_hl("NeotestIndent",       { ctermfg = "Grey",    fg = "#a89984" })
      set_hl("NeotestExpandMarker", { ctermfg = "Grey",    fg = "#bdae93" })
      set_hl("NeotestAdapterName",  { ctermfg = "Red",     fg = "#cc241d" })
      set_hl("NeotestWinSelect",    { ctermfg = "Cyan",    fg = "#83a598", bold = true })
      set_hl("NeotestMarked",       { ctermfg = "Brown",   fg = "#fe8019", bold = true })
      set_hl("NeotestTarget",       { ctermfg = "Red",     fg = "#cc241d" })
      set_hl("NeotestUnknown",      { link    = "Normal" })
    end

    --- Override Neotest default theme
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if theme == "gruvbox" then
      local augroup = vim.api.nvim_create_augroup("NeotestColorSchemeRefresh", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { callback = define_gruvbox_highlights, group = augroup })
      define_gruvbox_highlights()
    end
  end
}
