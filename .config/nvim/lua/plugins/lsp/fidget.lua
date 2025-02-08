-- fidget.nvim (https://github.com/j-hui/fidget.nvim)
--   Standalone UI for nvim-lsp progress

return {
  "j-hui/fidget.nvim",
  event = "LspAttach",
  opts = {
    progress = {
      ignore = { "null-ls" },
    },
  },
}
