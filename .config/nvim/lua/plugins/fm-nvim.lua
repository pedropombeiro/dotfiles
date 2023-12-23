-- fm-nvim (https://github.com/is0n/fm-nvim)
-- 🗂 Neovim plugin that lets you use your favorite terminal file managers (and fuzzy finders) from within Neovim.

return {
  {
    'vifm/vifm.vim', -- Import for ftplugin, ftdetect, and syntax definitions
    event = { 'BufNewFile', 'BufReadPre' },
    init = function()
      vim.g.loaded_vifm = 1
    end,
  },

  {
    'is0n/fm-nvim',
    init = function()
      if vim.fn.has('mac') == 1 then -- Ensure that LazyGit uses same config dir on macOS as in Linux
        vim.api.nvim_create_autocmd({ 'BufEnter', 'BufAdd', 'BufNew', 'BufNewFile', 'BufWinEnter' }, {
          group = vim.api.nvim_create_augroup('LAZYGIT_CUSTOM_CONFIG', {}),
          callback = function()
            vim.g.lazygit_use_custom_config_file_path = 1
            vim.g.lazygit_config_file_path = vim.fn.expand('~/.config/lazygit/config.yml')
          end,
        })
      end
    end,
    keys = {
      {
        '<leader>tg',
        function()
          if vim.env.GIT_DIR == nil then
            vim.cmd('cd %:h') -- Ensure we're calling Lazygit from the folder of the active file
          end
          vim.cmd('Lazygit')
        end,
        desc = 'Open LazyGit',
      },
      {
        '<leader>F',
        function()
          -- Signal to vifm that we don't want image previews, since we can't really calculate the correct offset of the popup
          vim.env._DISABLE_VIFM_IMGPREVIEW = '1'
          if vim.api.nvim_buf_get_name(0) == '' then
            vim.cmd([[Vifm --select %:p:h]])
          else
            vim.cmd([[Vifm --select %]])
          end
          vim.env._DISABLE_VIFM_IMGPREVIEW = ''
        end,
        desc = 'Open File Manager (vifm)',
      },
    },
    opts = {
      ui = {
        float = {
          height = 0.9,
          width = 0.9,
          -- Floating window border (see ':h nvim_open_win')
          border = 'rounded',
        },
      },
    },
  },
}
