-- diffview.nvim (https://github.com/sindrets/diffview.nvim)
--   Single tabpage interface for easily cycling through diffs for all modified files for any git rev.

return {
  "sindrets/diffview.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  ---@type LazyKeysSpec[]
  keys = { { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "DiffView" } },
  opts = function()
    local config = require("config")

    return {
      icons = {
        folder_closed = config.ui.icons.folder.collapsed,
        folder_open = config.ui.icons.folder.expanded,
      },
      signs = {
        fold_closed = config.ui.icons.expander.collapsed,
        fold_open = config.ui.icons.expander.expanded,
      },
    }
  end,
}
