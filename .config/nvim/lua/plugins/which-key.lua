-- which-key (https://github.com/folke/which-key.nvim)
--   💥 Create key bindings that stick. WhichKey is a lua plugin for Neovim 0.5 that displays
--   a popup with possible keybindings of the command you started typing.

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    require("plugins/which-key.keymap")
    require("plugins/which-key.keymap-plugins")
  end,
  ---@type LazyKeysSpec[]
  keys = {
    {
      "<leader>?",
      function() require("which-key").show({ global = false }) end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
