-- fm-nvim (https://github.com/is0n/fm-nvim)
-- 🗂 Neovim plugin that lets you use your favorite terminal file managers (and fuzzy finders) from within Neovim.

return {
  'vifm/vifm.vim', -- Import for ftplugin, ftdetect, and syntax definitions

  {
    'is0n/fm-nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<leader>F',
        function()
          if vim.api.nvim_buf_get_name(0) == '' then
            vim.cmd [[Vifm --select %:p:h]]
          else
            vim.cmd [[Vifm --select %]]
          end
        end,
        desc = 'Open File Manager (vifm)',
      }
    },
    opts = {
      ui = {
        float = {
          height    = 0.9,
          width     = 0.9,
          -- Floating window border (see ':h nvim_open_win')
          border = 'single'
        }
      }
    }
  }
}
