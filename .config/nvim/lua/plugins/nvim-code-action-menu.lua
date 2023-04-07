-- NeoVim Code Action Menu (https://github.com/weilbith/nvim-code-action-menu)
--  Pop-up menu for code actions to show meta-information and diff preview

return {
  'weilbith/nvim-code-action-menu', -- Pop-up menu for code actions to show meta-information and diff preview
  cmd = 'CodeActionMenu',
  keys = {
    { '<leader>la', ':CodeActionMenu<CR>', desc = 'Open code action menu' }
  }
}
