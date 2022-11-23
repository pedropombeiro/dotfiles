-- vim-fugitive (https://github.com/tpope/vim-fugitive)
--  fugitive.vim: A Git wrapper so awesome, it should be illegal

-- Every time you open a git object using fugitive it creates a new buffer.
-- This means that your buffer listing can quickly become swamped with
-- fugitive buffers. This prevents this from becomming an issue:

local fugitive_augroup = vim.api.nvim_create_augroup("fugitive", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "fugitive://*",
  group = fugitive_augroup,
  command = "set bufhidden=delete"
})
