-- fidget.nvim (https://github.com/j-hui/fidget.nvim)
--  Extensible UI for Neovim notifications and LSP progress messages.

return {
  "j-hui/fidget.nvim",
  event = "LspAttach",
  opts = {
    progress = {
      ignore = { "null-ls" },
    },
  },
}
