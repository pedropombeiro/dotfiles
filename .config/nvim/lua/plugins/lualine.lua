-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

return {
  'nvim-lualine/lualine.nvim',
  event = { 'BufNewFile', 'BufReadPre' },
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  dependencies = {
    'kyazdani42/nvim-web-devicons',
  },
  init = function()
    local opt = vim.opt

    opt.showmode = false -- The mode is shown in Lualine anyway
    opt.showcmd = false -- The selected line count is already shown in Lualine
    if vim.fn.has('nvim-0.9') == 1 then
      opt.shortmess:append({ S = true }) -- do not show search count message when searching
    end
  end,
  opts = function()
    local config = require('config')
    local diagnostic_icons = config.ui.icons.diagnostics
    local symbol_icons = config.ui.icons.symbols

    return {
      options = {
        icons_enabled = true,
        ignore_focus = { 'neotest-summary', 'lazygit', 'TelescopePrompt' },
        disabled_filetypes = {
          statusline = { 'alpha', 'Fm', 'mason', 'neotest-summary' },
        },
        globalstatus = true,
        theme = 'gruvbox',
      },
      extensions = {
        'fugitive',
        'man',
        'lazy',
        'neo-tree',
        'nvim-dap-ui',
        'symbols-outline',
        'trouble',
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch' },
        lualine_c = {
          {
            'diagnostics',
            symbols = {
              ---@diagnostic disable: undefined-field
              hint = diagnostic_icons.hint .. ' ',
              info = diagnostic_icons.info .. ' ',
              warn = diagnostic_icons.warning .. ' ',
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
            },
          },
        },
        lualine_x = {
          {
            function()
              return diagnostic_icons.debug .. '  ' .. require('dap').status()
            end,
            cond = function()
              return package.loaded['dap'] and require('dap').status() ~= ''
            end,
          },
          {
            require('lazy.status').updates,
            cond = require('lazy.status').has_updates,
          },
          {
            'diff',
            symbols = {
              ---@diagnostic disable: undefined-field
              added = symbol_icons.added .. ' ',
              modified = symbol_icons.modified .. ' ',
              removed = symbol_icons.removed .. ' ',
              ---@diagnostic enable: undefined-field
            },
          },
          'encoding',
          'fileformat',
          'filetype',
        },
        lualine_y = {
          'selectioncount',
          { 'searchcount', maxcount = 999, timeout = 500 },
        },
        lualine_z = {
          'progress',
          'location',
        },
      },
    }
  end,
}
