-- vim-easy-align (https://github.com/junegunn/vim-easy-align)
--  🌻 A Vim alignment plugin

return {
  'junegunn/vim-easy-align',
  event = { 'BufNewFile', 'BufReadPost' },
  keys = {
    --- Start interactive EasyAlign in visual mode (e.g. vipga) and for a motion/text object (e.g. gaip)
    { 'ga', '<Plug>(EasyAlign)', mode = { 'n', 'x' }, desc = 'Easy Align' },
  },
}
