-- fm-nvim (https://github.com/is0n/fm-nvim)
-- 🗂 Neovim plugin that lets you use your favorite terminal file managers (and fuzzy finders) from within Neovim.

return {
  'vifm/vifm.vim', -- Import for ftplugin, ftdetect, and syntax definitions

  {
    'is0n/fm-nvim',
    event = 'VeryLazy',
    keys = {
      { '<leader>F', ':Vifm %:p:h<CR>', desc = 'Open File Manager (vifm)' }
    },
    opts = {
      ui = {
        float = {
          -- Floating window border (see ':h nvim_open_win')
          border = 'single'
        }
      }
    }
  }
}
