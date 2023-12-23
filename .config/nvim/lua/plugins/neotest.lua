-- Neotest (https://github.com/nvim-neotest/neotest)
--  An extensible framework for interacting with tests within NeoVim.

---@format disable-next
-- stylua: ignore
local keys = {
  { '<leader>rt', function() require('neotest').run.run() end,                     desc = 'Run the nearest test' },
  { '<leader>rd', function() require('neotest').run.run({ strategy = 'dap' }) end, desc = 'Debug the nearest test' },
  { '<leader>rf', function() require('neotest').run.run(vim.fn.expand('%')) end,   desc = 'Run the current file' },
  { '<leader>rl', function() require('neotest').run.run_last() end,                desc = 'Repeat last test run' },
  { '<leader>rr', function() require('neotest').summary.open() end,                desc = 'Open test summary' },
  { '<leader>ro', function() require('neotest').output.open({ enter = true }) end, desc = 'Open test output' },
}

return {
  'nvim-neotest/neotest',
  ft = { 'go', 'ruby' },
  keys = keys,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'antoinemadec/FixCursorHold.nvim',

    'nvim-neotest/neotest-go',
    {
      'olimorris/neotest-rspec',
      keys = {
        {
          '<leader>rb',
          ":Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')<CR>",
          desc = 'Run MR tests',
        },
      },
    },
  },
  init = function()
    -- Keymaps
    local m = require('mapx')
    m.nname('<leader>r', 'Test')
  end,
  config = function(_, opts)
    -- get neotest namespace (api call creates or returns namespace)
    local neotest_ns = vim.api.nvim_create_namespace('neotest')
    vim.diagnostic.config({
      virtual_text = {
        format = function(diagnostic)
          local message = diagnostic.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '')
          return message
        end,
      },
    }, neotest_ns)

    local neotest = require('neotest')
    local config = require('config')
    local icons = config.ui.icons
    neotest.setup(opts)

    -- Theming (from https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/config/init.lua)
    local function set_hl(name, attr)
      vim.api.nvim_set_hl(0, name, attr)
    end

    ---@format disable-next
    local function define_highlights()
      ---@diagnostic disable: undefined-field
      set_hl('NeotestPassed', { ctermfg = 'Green', fg = config.theme.colors.green })
      set_hl('NeotestFailed', { ctermfg = 'Red', fg = config.theme.colors.dark_red })
      set_hl('NeotestRunning', { ctermfg = 'Yellow', fg = config.theme.colors.dark_yellow })
      set_hl('NeotestSkipped', { ctermfg = 'Cyan', fg = config.theme.colors.dark_blue })
      set_hl('NeotestTest', { link = 'Normal' })
      set_hl('NeotestNamespace', { ctermfg = 'Magenta', fg = config.theme.colors.purple })
      set_hl('NeotestFocused', { bold = true, underline = true })
      set_hl('NeotestFile', { ctermfg = 'Cyan', fg = config.theme.colors.dark_blue })
      set_hl('NeotestDir', { ctermfg = 'Cyan', fg = config.theme.colors.dark_blue })
      set_hl('NeotestIndent', { ctermfg = 'Grey', fg = config.theme.colors.fg4 })
      set_hl('NeotestExpandMarker', { ctermfg = 'Grey', fg = config.theme.colors.fg3 })
      set_hl('NeotestAdapterName', { ctermfg = 'Red', fg = config.theme.colors.red })
      set_hl('NeotestWinSelect', { ctermfg = 'Cyan', fg = config.theme.colors.dark_blue, bold = true })
      set_hl('NeotestMarked', { ctermfg = 'Brown', fg = config.theme.colors.orange, bold = true })
      set_hl('NeotestTarget', { ctermfg = 'Red', fg = config.theme.colors.red })
      set_hl('NeotestUnknown', { link = 'Normal' })
      ---@diagnostic enable: undefined-field
    end

    --- Override Neotest default theme
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    ---@diagnostic disable-next-line: undefined-field
    if theme == config.theme.name then
      local augroup = vim.api.nvim_create_augroup('NeotestColorSchemeRefresh', { clear = true })
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = 'gruvbox',
        callback = define_highlights,
        group = augroup,
      })
      define_highlights()
    end
  end,
  opts = function()
    return {
      adapters = {
        require('neotest-go')({
          experimental = {
            test_table = true,
          },
          args = { '-count=1', '-timeout=60s' },
        }),
        require('neotest-rspec')({
          rspec_cmd = function()
            return vim.tbl_flatten({
              'bundle',
              'exec',
              'rspec',
            })
          end,
        }),
      },
      icons = {
        ---@diagnostic disable: undefined-field
        expanded = icons.expander.expanded,
        child_prefix = '',
        child_indent = '',
        final_child_prefix = '',
        non_collapsible = '',
        collapsed = icons.expander.collapsed,
        passed = icons.tests.passed,
        running = icons.tests.running,
        failed = icons.tests.failed,
        unknown = icons.tests.unknown,
        ---@diagnostic enable: undefined-field
      },
      quickfix = {
        open = function()
          vim.cmd('Trouble quickfix')
        end,
      },
    }
  end,
}
