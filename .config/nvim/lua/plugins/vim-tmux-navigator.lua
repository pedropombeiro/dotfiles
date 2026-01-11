-- vim-tmux-navigator (https://github.com/christoomey/vim-tmux-navigator)
--   Seamless navigation between tmux panes and vim splits

return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  keys = {
    { "<M-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux/vim)" },
    { "<M-j>", "<cmd><C-U>TmuxNavigateDown<cr>", desc = "Navigate down (tmux/vim)" },
    { "<M-k>", "<cmd><C-U>TmuxNavigateUp<cr>", desc = "Navigate up (tmux/vim)" },
    { "<M-l>", "<cmd><C-U>TmuxNavigateRight<cr>", desc = "Navigate right (tmux/vim)" },
    { "<M-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>", desc = "Navigate to previous (tmux/vim)" },
  },
}
