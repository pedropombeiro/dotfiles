-- indent-blankline.nvim (https://github.com/lukas-reineke/indent-blankline.nvim)
--  Indent guides for Neovim

local filetype_exclude = { 'help', 'alpha', 'dashboard', 'neo-tree', 'Trouble', 'lazy', 'mason' }
local symbol = '│'

return {
  {
    'lukas-reineke/indent-blankline.nvim', -- Indent guides for Neovim
    main = 'ibl',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      indent = {
        char = symbol
      },
      exclude = { filetypes = filetype_exclude },
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
        animation = function(next, _total)
          return 5
        end
      }
    },
  },
}
