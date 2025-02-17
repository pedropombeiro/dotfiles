-- fm-nvim (https://github.com/is0n/fm-nvim)
-- 🗂 Neovim plugin that lets you use your favorite terminal file managers (and fuzzy finders) from within Neovim.

return {
  {
    "vifm/vifm.vim", -- Import for ftplugin, ftdetect, and syntax definitions
    event = { "BufNewFile", "BufReadPre" },
  },

  {
    "is0n/fm-nvim",
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      {
        "<leader>F",
        function()
          -- Signal to vifm that we don't want image previews, since we can't really calculate the correct offset of the popup
          vim.env._DISABLE_VIFM_IMGPREVIEW = "1"
          if vim.api.nvim_buf_get_name(0) == "" then
            vim.cmd([[Vifm --select %:p:h]])
          else
            vim.cmd([[Vifm --select %]])
          end
          vim.env._DISABLE_VIFM_IMGPREVIEW = ""
        end,
        desc = "Open File Manager (vifm)",
      },
    },
    opts = {
      cmds = {
        vifm_cmd = "vifm",
        lazygit_cmd = "lazygit --use-config-dir ~/.config/lazygit",
      },
      ui = {
        float = {
          height = 0.9,
          width = 0.9,
          -- Floating window border (see ':h nvim_open_win')
          border = require("config").ui.border,
          float_hl = "NormalFloat",
        },
      },
    },
  },
}
