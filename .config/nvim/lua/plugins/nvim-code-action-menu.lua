-- NeoVim Code Action Menu (https://github.com/aznhe21/actions-preview.nvim)
--  Fully customizable previewer for LSP code actions.

return {
  'aznhe21/actions-preview.nvim',
  cmd = 'CodeActionMenu',
  keys = {
    {
      '<leader>la',
      function()
        require('actions-preview').code_actions()
      end,
      desc = 'Open code action menu',
    },
  },
}
