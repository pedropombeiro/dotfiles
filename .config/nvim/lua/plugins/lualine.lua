-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  dependencies = {
    { 'arkav/lualine-lsp-progress',   lazy = true, event = 'BufReadPost' }, -- LSP Progress lualine component
    { 'kyazdani42/nvim-web-devicons', lazy = true },
  },
  init = function()
    local opt = vim.opt

    opt.showmode = false                 -- The mode is shown in Lualine anyway
    opt.showcmd = false                  -- The selected line count is already shown in Lualine
    if vim.fn.has('nvim-0.9') == 1 then
      opt.shortmess:append({ S = true }) -- do not show search count message when searching
    end
  end,
  opts = function()
    local config           = require('config')
    local colors           = config.theme.colors
    local diagnostic_icons = config.icons.diagnostics
    local symbol_icons     = config.icons.symbols

    return {
      options = {
        icons_enabled = true,
        ignore_focus = { 'neotest-summary', 'lazygit', 'TelescopePrompt' },
        disabled_filetypes = {
          statusline = { 'alpha', 'mason', 'neotest-summary' },
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
        'trouble'
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch' },
        lualine_c = {
          {
            'diagnostics',
            symbols = {
              ---@diagnostic disable: undefined-field
              hint  = diagnostic_icons.hint .. ' ',
              info  = diagnostic_icons.info .. ' ',
              warn  = diagnostic_icons.warning .. ' ',
              error = diagnostic_icons.error .. ' ',
              ---@diagnostic enable: undefined-field
            },
          },
          { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
          {
            'filename',
            show_filename_only = false,
            path = 1,
            shorting_target = 80,
            symbols = {
              modified = symbol_icons.modified,
              readonly = symbol_icons.readonly, -- Text to show when the file is non-modifiable or readonly.
            }
          },
          {
            'lsp_progress',
            colors = {
              ---@diagnostic disable: undefined-field
              percentage      = colors.cyan,
              title           = colors.blue,
              message         = colors.blue,
              spinner         = colors.cyan,
              lsp_client_name = colors.purple,
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
            function() return diagnostic_icons.debug .. '  ' .. require('dap').status() end,
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
              added    = symbol_icons.added .. ' ',
              modified = symbol_icons.modified .. ' ',
              removed  = symbol_icons.removed .. ' ',
              ---@diagnostic enable: undefined-field
            }
          },
          'encoding',
          'fileformat',
          'filetype'
        },
        lualine_y = {
          'selectioncount',
          { 'searchcount', maxcount = 999, timeout = 500, },
        },
        lualine_z = {
          'progress',
          'location',
        }
      }
    }
  end
}
