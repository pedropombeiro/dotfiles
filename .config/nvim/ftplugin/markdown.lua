vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("x", "<leader>u", 'c[<C-r>"]()<Esc>i', { buffer = true, noremap = true, silent = true })
  end,
})
