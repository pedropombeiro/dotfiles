-- Bclose (https://github.com/rbgrouleff/bclose.vim)
--  The BClose Vim plugin for deleting a buffer without closing the window

return {
  'rbgrouleff/bclose.vim',
  cmd = 'Bclose',
  keys = {
    { '<leader>bd', '<Cmd>Bclose<CR>', desc = 'Close buffer' },
  },
  init = function()
    require('which-key').add({
      { '<leader>b', group = 'Bclose' },
    })
  end,
}
