-- lsp_lines (https://git.sr.ht/~whynothugo/lsp_lines.nvim)
--  lsp_lines is a simple neovim plugin that renders diagnostics using virtual lines on top of the real line of code.

require("lsp_lines").setup()

-- Disable virtual_text since it's redundant due to lsp_lines.
vim.diagnostic.config({
  virtual_text = false,
})
