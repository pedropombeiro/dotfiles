-- vim-tmux-navigator (https://github.com/christoomey/vim-tmux-navigator)
--   Seamless navigation between tmux panes and vim splits

return {
  "christoomey/vim-tmux-navigator",
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  keys = {
    { "<M-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux/vim)", mode = { "n", "t" } },
    { "<M-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (tmux/vim)", mode = { "n", "t" } },
    { "<M-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (tmux/vim)", mode = { "n", "t" } },
    { "<M-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux/vim)", mode = { "n", "t" } },
    { "<M-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Navigate to previous (tmux/vim)", mode = { "n", "t" } },
  },
}
