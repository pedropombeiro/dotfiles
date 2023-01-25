-- This means that your buffer listing can quickly become swamped with
-- fugitive buffers. This prevents this from becomming an issue:

return {
  "tpope/vim-fugitive",
  cmd = {
    "Git", "Gedit", "Gdiffsplit", "Gvdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete"
  },
  init = function()
    local fugitive_augroup = vim.api.nvim_create_augroup("fugitive", { clear = true })

    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = "fugitive://*",
      group = fugitive_augroup,
      command = "set bufhidden=delete"
    })
  end
}
