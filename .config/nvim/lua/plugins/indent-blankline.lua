-- indent-blankline.nvim (https://github.com/lukas-reineke/indent-blankline.nvim)
--  Indent guides for Neovim

local filetype_exclude = { 'help', 'alpha', 'dashboard', 'neo-tree', 'Trouble', 'lazy', 'mason' }
local symbol = '│'

return {
  {
    'lukas-reineke/indent-blankline.nvim', -- Indent guides for Neovim
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      char = symbol,
      filetype_exclude = filetype_exclude,
      show_trailing_blankline_indent = false,
      show_current_context = false,
    },
  },
  {
    'echasnovski/mini.indentscope', -- Visualize and work with indent scope
    version = false,
    event = { 'BufReadPre', 'BufNewFile' },
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetype_exclude,
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
    opts = {
      symbol = symbol,
      options = { try_as_border = true },
      draw = {
        animation = function(next, total)
          return 5
        end
      }
    },
  },
}
