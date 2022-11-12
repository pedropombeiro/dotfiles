-- fzf.vim (https://github.com/junegunn/fzf.vim/)
--  fzf ❤️ vim

-- [Buffers] Jump to the existing window if possible
vim.g.fzf_buffers_jump = true

-- [Commands] --expect expression for directly executing the command
vim.g.fzf_commands_expect = "alt-enter,ctrl-x"

vim.api.nvim_create_user_command(
  "GGrep",
  "call fzf#vim#grep('git grep --line-number -- '.shellescape(<q-args>), 0, "
  .. "fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), "
  .. "<bang>0)"
  , {})

local function map(mode, l, r, opts)
  opts = opts or {}
  vim.keymap.set(mode, l, r, opts)
end

map("n", "<leader>ff", "<Cmd>FZF<CR>", { noremap = true })

map("n", "<leader>fc", "<Cmd>Commits<CR>")
map("n", "<leader>fg", "<Cmd>GFiles<CR>")
map("n", "<leader>fG", "<Cmd>GFiles?<CR>")
map("n", "<leader>fh", "<Cmd>History<CR>")
map("n", "<leader>f:", "<Cmd>History:<CR>")
map("n", "<leader>f/", "<Cmd>History/<CR>")
map("n", "<leader>fr", "<Cmd>Rg<CR>")

--" Mapping selecting mappings
map("n", "<leader><tab>", "<Plug>(fzf-maps-n)")
map("x", "<leader><tab>", "<Plug>(fzf-maps-x)")
map("o", "<leader><tab>", "<Plug>(fzf-maps-o)")

--" Insert mode completion
map("i", "<C-x><C-k>", "<Plug>(fzf-complete-word)")
map("i", "<C-x><C-f>", "<Plug>(fzf-complete-path)")
map("i", "<C-x><C-l>", "<Plug>(fzf-complete-line)")
