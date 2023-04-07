-- nvim-lightbulb.vim (https://github.com/kosayoda/nvim-lightbulb)
--  VSCode 💡 for neovim's built-in LSP.

return {
  'kosayoda/nvim-lightbulb',
  event = 'BufReadPre',
  dependencies = 'antoinemadec/FixCursorHold.nvim',
  opts = {
    autocmd = { enabled = true }
  }
}
