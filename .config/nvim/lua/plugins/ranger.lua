-- Ranger.nvim (https://github.com/kelly-lin/ranger.nvim)
--  Ranger plugin for neovim

return {
  'kelly-lin/ranger.nvim',
  keys = {
    {
      '<leader>R',
      function()
        require('ranger-nvim').open(true)
      end,
      desc = 'Open Ranger'
    }
  },
  config = function()
    require('ranger-nvim').setup({ replace_netrw = false })
  end,
}
