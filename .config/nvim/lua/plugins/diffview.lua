-- codediff.nvim (https://github.com/esmuellert/codediff.nvim)
--   VSCode-style side-by-side diff rendering with two-tier highlighting.

return {
  "esmuellert/codediff.nvim",
  dependencies = "MunifTanjim/nui.nvim",
  cmd = "CodeDiff",
  ---@module "lazy"
  ---@type LazyKeysSpec[]
  keys = { { "<leader>gd", "<cmd>CodeDiff<cr>", desc = "CodeDiff" } },
  opts = function()
    ---@type pmsp.neovim.Config
    local config = require("config")

    return {
      explorer = {
        icons = {
          folder_closed = config.ui.icons.folder.collapsed,
          folder_open = config.ui.icons.folder.expanded,
        },
      },
    }
  end,
}
