-- indent-blankline.nvim (https://github.com/lukas-reineke/indent-blankline.nvim)
--  Indent guides for Neovim

local filetype_exclude = {
  'help',
  'snacks_dashboard',
  'dashboard',
  'neo-tree',
  'Trouble',
  'trouble',
  'lazy',
  'mason',
  'notify',
  'toggleterm',
  'lazyterm',
}
local symbol = '│'

return {
  {
    'lukas-reineke/indent-blankline.nvim', -- Indent guides for Neovim
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
    opts = {
      indent = {
        char = symbol,
      },
      exclude = { filetypes = filetype_exclude },
    },
  },
  {
    'echasnovski/mini.indentscope', -- Visualize and work with indent scope
    version = false, -- wait till new 0.7.0 release to put it back on semver
    event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
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
        end,
      },
    },
  },
}
