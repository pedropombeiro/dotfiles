-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  dependencies = {
    { 'arkav/lualine-lsp-progress', lazy = true, event = 'BufReadPost' }, -- LSP Progress lualine component
    'kyazdani42/nvim-web-devicons',
  },
  init = function()
    vim.opt.showmode = false -- The mode is shown in Lualine anyway
  end,
  opts = function()
    local config = require('config')

    return {
      options = {
        icons_enabled = true,
        ignore_focus = { 'neotest-summary', 'TelescopePrompt', 'Trouble' },
        disabled_filetypes = {
          statusline = { 'alpha', 'neotest-summary', 'Trouble' },
        },
        globalstatus = true,
      },
      extensions = {
        'fugitive',
        'man',
        'lazy',
        'neo-tree',
        'nvim-dap-ui',
        'symbols-outline',
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch' },
        lualine_c = {
          {
            'diagnostics',
            symbols = {
              ---@diagnostic disable: undefined-field
              hint  = config.icons.diagnostics.hint .. ' ',
              info  = config.icons.diagnostics.info .. ' ',
              warn  = config.icons.diagnostics.warning .. ' ',
              error = config.icons.diagnostics.error .. ' ',
              ---@diagnostic enable: undefined-field
            },
          },
          { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
          {
            'filename',
            show_filename_only = false,
            path = 1,
            shorting_target = 80,
          },
          {
            'lsp_progress',
            colors = {
              ---@diagnostic disable: undefined-field
              percentage      = config.theme.colors.cyan,
              title           = config.theme.colors.blue,
              message         = config.theme.colors.blue,
              spinner         = config.theme.colors.cyan,
              lsp_client_name = config.theme.colors.purple,
              use             = true,
              ---@diagnostic enable: undefined-field
            },
            separators = {
              component = ' ',
              progress = ' | ',
              percentage = { pre = '', post = '%% ' },
              title = { pre = '', post = ': ' },
              lsp_client_name = { pre = '[', post = ']' },
              spinner = { pre = '', post = '' },
              message = { pre = '(', post = ')', commenced = 'In Progress', completed = 'Completed' },
            },
            display_components = { 'lsp_client_name', 'spinner', { 'title', 'percentage', 'message' } },
            timer = { progress_enddelay = 500, spinner = 1000, lsp_client_name_enddelay = 1000 },
            spinner_symbols = { '🌑 ', '🌒 ', '🌓 ', '🌔 ', '🌕 ', '🌖 ', '🌗 ', '🌘 ' },
          }
        },
        lualine_x = {
          {
            function() return config.icons.diagnostics.debug .. '  ' .. require('dap').status() end,
            cond = function() return package.loaded['dap'] and require('dap').status() ~= '' end,
          },
          {
            require('lazy.status').updates,
            cond = require('lazy.status').has_updates,
          },
          {
            'diff',
            symbols = {
              ---@diagnostic disable: undefined-field
              added    = config.icons.symbols.added .. ' ',
              modified = config.icons.symbols.modified .. ' ',
              removed  = config.icons.symbols.removed .. ' ',
              ---@diagnostic enable: undefined-field
            }
          },
          'encoding',
          'fileformat',
          'filetype'
        },
        lualine_y = { 'progress' },
        lualine_z = { 'location' }
      }
    }
  end
}
