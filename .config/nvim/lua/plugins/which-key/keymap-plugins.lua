--- key bindings -------------------------------------------------------------------

require('which-key').add({
  { '<leader>g', group = 'Git / Change action' },

  -- folke/persistence.nvim
  { '<leader>q', group = 'Session management' },

  -- ruifm/gitlinker.nvim
  { '<leader>gy', mode = { 'n', 'v' }, desc = 'Yank Git URL' },

  -- Lazy.nvim
  { '<leader>p', group = 'Package Manager', icon = '' },
  { '<leader>ps', ':Lazy<CR>', desc = 'Status', icon = '󱖫' },
  { '<leader>pu', ':Lazy sync<CR>', desc = 'Sync', icon = '' },

  -- wsdjeg/vim-fetch
  { 'gF', mode = { 'n', 'x' }, desc = 'Go to file:line under cursor' },
})
