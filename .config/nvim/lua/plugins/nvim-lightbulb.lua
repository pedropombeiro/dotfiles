-- nvim-lightbulb.vim (https://github.com/kosayoda/nvim-lightbulb)
--  VSCode 💡 for neovim's built-in LSP.

return {
  "kosayoda/nvim-lightbulb",
  dependencies = "antoinemadec/FixCursorHold.nvim",
  config = function()
    require "nvim-lightbulb".setup {
      autocmd = { enabled = true }
    }
  end
}
