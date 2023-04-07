--- key bindings -------------------------------------------------------------------

local wk = require('which-key')
local m = require('mapx')

m.nname('<leader>g', 'Git')

-- Lazy.nvim
m.nname('<leader>p', 'Package Manager')
m.nnoremap('<leader>ps', ':Lazy<CR>', 'Status')
m.nnoremap('<leader>pu', ':Lazy sync<CR>', 'Sync')

-- wsdjeg/vim-fetch
wk.register({
  ['gF'] = { 'Go to file:line under cursor' },
}, { mode = { 'n', 'x' } })
