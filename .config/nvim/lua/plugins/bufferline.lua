-- bufferline.nvim (https://github.com/akinsho/bufferline.nvim)
--  A snazzy bufferline for Neovim

return {
  'akinsho/bufferline.nvim',
  dependencies = 'kyazdani42/nvim-web-devicons',
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  event = 'VeryLazy',
  keys = {
    { '<leader>bp', '<Cmd>BufferLineTogglePin<CR>',            desc = 'Toggle pin' },
    { '<leader>bP', '<Cmd>BufferLineGroupClose ungrouped<CR>', desc = 'Delete non-pinned buffers' },
  },
  opts = {
    options = {
      groups = {
        options = {
          toggle_hidden_on_enter = true -- when you re-enter a hidden group this options re-opens that group so the buffer is visible
        },
        items = {
          {
            name       = 'Docs',
            highlight  = { underline = true, sp = 'green' },
            auto_close = true, -- whether or not close this group if it doesn't contain the current buffer
            matcher    = function(buf)
              return buf.filename:match('%.md') or buf.filename:match('%.txt')
            end
          },
          {
            name       = 'DB',
            highlight  = { underline = true, sp = 'red' },
            auto_close = true, -- whether or not close this group if it doesn't contain the current buffer
            matcher    = function(buf)
              return buf.path:match('%/gitlab/db/')
            end
          },
          {
            name    = 'EE',
            matcher = function(buf)
              return buf.path:match('%/gitlab/ee/')
            end
          },
          {
            name       = 'Tests',                           -- Mandatory
            highlight  = { underline = true, sp = 'blue' }, -- Optional
            icon       = '',                             -- Optional
            auto_close = true,                              -- whether or not close this group if it doesn't contain the current buffer
            matcher    = function(buf)                      -- Mandatory
              return buf.filename:match('%_test') or buf.filename:match('%_spec')
            end,
          },
        }
      },
      separator_style = 'slant',
      diagnostics = 'nvim_lsp',
      always_show_bufferline = false,
      diagnostics_indicator = function(_, _, diag)
        ---@diagnostic disable: undefined-field
        local icons = require('config').icons.diagnostics
        ---@diagnostic enable: undefined-field
        local ret = (diag.error and (icons.error .. ' ' .. diag.error) or '')
            .. (diag.warning and (icons.warning .. ' ' .. diag.warning) or '')
        return ret
      end,
      offsets = {
        {
          filetype = 'neo-tree',
          text = 'Neo-tree',
          highlight = 'Directory',
          text_align = 'left',
        },
      },
    },
  },
}
