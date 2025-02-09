-- Neotest (https://github.com/nvim-neotest/neotest)
--  An extensible framework for interacting with tests within NeoVim.

---@format disable-next
-- stylua: ignore
local keys = {
  { '<leader>rt', function() require('neotest').run.run() end,                        desc = 'Run the nearest test' },
  { '<leader>rd', function() require('neotest').run.run({ strategy = 'dap' }) end,    desc = 'Debug the nearest test' },
  { '<leader>rf', function() require('neotest').run.run(vim.fn.expand('%')) end,      desc = 'Run the current file' },
  { '<leader>rl', function() require('neotest').run.run_last() end,                   desc = 'Repeat last test run' },
  { '<leader>rr', function() require('neotest').summary.open() end,                   desc = 'Open test summary' },
  { '<leader>ro', function() require('neotest').output.open({ enter = true }) end,    desc = 'Open test output' },
  { '<leader>rw', function() require('neotest').watch.toggle(vim.fn.expand("%")) end, desc = 'Watch current file' },
}

return {
  "nvim-neotest/neotest",
  ft = { "go", "ruby" },
  keys = keys,
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",

    "nvim-neotest/neotest-go",
    {
      "olimorris/neotest-rspec",
      keys = {
        {
          "<leader>rb",
          ":Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')<CR>",
          desc = "Run MR tests",
        },
      },
    },
  },
  init = function() require("which-key").add({ { "<leader>r", group = "Test", icon = "󰙨" } }) end,
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

    local config = require("config")
    local icons = config.ui.icons

    ---@format disable-next
    local function define_highlights()
      ---@diagnostic disable: undefined-field
      Set_hl({
        Passed = { ctermfg = "Green", fg = config.theme.colors.green },
        Failed = { ctermfg = "Red", fg = config.theme.colors.dark_red },
        Running = { ctermfg = "Yellow", fg = config.theme.colors.dark_yellow },
        Skipped = { ctermfg = "Cyan", fg = config.theme.colors.dark_blue },
        Test = { link = "Normal" },
        Namespace = { ctermfg = "Magenta", fg = config.theme.colors.purple },
        Focused = { bold = true, underline = true },
        File = { ctermfg = "Cyan", fg = config.theme.colors.dark_blue },
        Dir = { ctermfg = "Cyan", fg = config.theme.colors.dark_blue },
        Indent = { ctermfg = "Grey", fg = config.theme.colors.fg4 },
        ExpandMarker = { ctermfg = "Grey", fg = config.theme.colors.fg3 },
        AdapterName = { ctermfg = "Red", fg = config.theme.colors.red },
        WinSelect = { ctermfg = "Cyan", fg = config.theme.colors.dark_blue, bold = true },
        Marked = { ctermfg = "Brown", fg = config.theme.colors.orange, bold = true },
        Target = { ctermfg = "Red", fg = config.theme.colors.red },
        Unknown = { link = "Normal" },
      }, { prefix = "Neotest", default = true })
      ---@diagnostic enable: undefined-field
    end

    --- Override Neotest default theme
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    ---@diagnostic disable-next-line: undefined-field
    if theme == config.theme.name then
      local augroup = vim.api.nvim_create_augroup("NeotestColorSchemeRefresh", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "gruvbox",
        callback = define_highlights,
        group = augroup,
      })
      define_highlights()
    end

    ---@diagnostic disable-next-line: missing-fields
    require("neotest").setup({
      adapters = {
        require("neotest-go")({
          experimental = {
            test_table = true,
          },
          args = { "-count=1", "-timeout=60s" },
        }),
        require("neotest-rspec")({
          rspec_cmd = function() return { "bundle", "exec", "rspec" } end,
        }),
      },
      icons = {
        ---@diagnostic disable: undefined-field
        expanded = icons.expander.expanded,
        child_prefix = "",
        child_indent = "",
        final_child_prefix = "",
        non_collapsible = "",
        collapsed = icons.expander.collapsed,
        passed = icons.tests.passed,
        running = icons.tests.running,
        failed = icons.tests.failed,
        unknown = icons.tests.unknown,
        ---@diagnostic enable: undefined-field
      },
    })
  end,
}
