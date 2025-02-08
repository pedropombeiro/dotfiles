--- key bindings -------------------------------------------------------------------

require("which-key").add({
  { "<leader>g", group = "Git / Change action" },

  -- folke/persistence.nvim
  { "<leader>q", group = "Session management" },

  -- Lazy.nvim
  { "<leader>p", group = "Package Manager", icon = "" },
  { "<leader>ps", function() require("lazy").home() end, desc = "Status", icon = "󱖫" },
  { "<leader>pu", function() require("lazy").sync() end, desc = "Sync", icon = "" },

  -- wsdjeg/vim-fetch
  { "gF", mode = { "n", "x" }, desc = "Go to file:line under cursor" },
})
