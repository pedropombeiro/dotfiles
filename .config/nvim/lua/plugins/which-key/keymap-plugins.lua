--- key bindings -------------------------------------------------------------------

local wk = require('which-key')
local m = require('mapx')

m.nname('<leader>g', 'Git')

-- Lazy.nvim
m.nname('<leader>p', 'Package Manager')
m.nnoremap('<leader>ps', ':Lazy<CR>', 'Status', { silent = true })
m.nnoremap('<leader>pu', ':Lazy sync<CR>', 'Sync', { silent = true })

-- wsdjeg/vim-fetch
wk.register({
  ['gF'] = { 'Go to file:line under cursor' },
}, { mode = { 'n', 'x' } })

-- folke/persistence.nvim
m.nname('<leader>q', 'Session management')
