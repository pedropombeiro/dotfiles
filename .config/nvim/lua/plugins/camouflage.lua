return {
  "zeybek/camouflage.nvim",
  event = "VeryLazy",
  opts = {
    auto_enable = true,
    reveal = { follow_cursor = true },
    pwned = { enabled = false },
  },
  keys = {
    { "[om", function() require("camouflage").enable() end, desc = "Enable camouflage (mask secrets)" },
    { "]om", function() require("camouflage").disable() end, desc = "Disable camouflage (reveal secrets)" },
    { "<leader>ucy", "<cmd>CamouflageYank<CR>", desc = "Yank concealed value" },
  },
}
