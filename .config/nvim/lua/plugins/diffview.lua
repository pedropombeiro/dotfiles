-- diffview.nvim (https://github.com/sindrets/diffview.nvim)
--   Single tabpage interface for easily cycling through diffs for all modified files for any git rev.

return {
  "sindrets/diffview.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  keys = { { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "DiffView" } },
  config = true
}
