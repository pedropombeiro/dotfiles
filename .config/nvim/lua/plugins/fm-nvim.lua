-- fm-nvim (https://github.com/Eric-Song-Nop/fm-nvim)
-- 🗂 Neovim plugin that lets you use your favorite terminal file managers (and fuzzy finders) from within Neovim.

return {
  {
    "Eric-Song-Nop/fm-nvim",
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      {
        "<leader>F",
        function()
          if vim.api.nvim_buf_get_name(0) == "" then
            vim.cmd([[Yazi %:p:h]])
          else
            vim.cmd([[Yazi %]])
          end
        end,
        desc = "Open File Manager (yazi)",
      },
    },
    opts = {
      cmds = {
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
