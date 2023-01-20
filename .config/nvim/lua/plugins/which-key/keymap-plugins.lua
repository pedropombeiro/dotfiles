--- key bindings -------------------------------------------------------------------

local wk = require("which-key")
local m = require("mapx")
local silent = { silent = true }

-- vim-easy-align (https://github.com/junegunn/vim-easy-align)
--- Start interactive EasyAlign in visual mode (e.g. vipga) and for a motion/text object (e.g. gaip)
m.nnoremap("ga", "<Plug>(EasyAlign)", silent, "Easy Align")
m.xnoremap("ga", "<Plug>(EasyAlign)", silent, "Easy Align")

-- Restore URL handling from disabled netrw plugin
if vim.fn.has("mac") == 1 then
  m.nnoremap("gx", '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>', "Open URL")
elseif vim.fn.has("unix") == 1 then
  m.nnoremap("gx", '<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>', "Open URL")
else
  m.nnoremap("gx", '<Cmd>lua print("Error: gx is not supported on this OS!")<CR>', "Open URL")
end

-- Lazy.nvim
m.nname("<leader>p", "Package Manager")
m.nnoremap("<leader>ps", ":Lazy<CR>", "Status")
m.nnoremap("<leader>pu", ":Lazy sync<CR>", "Sync")

-- Splitjoin.vim
wk.register({
  S = { "Split into multi-line form" },
  J = { "Join into single-line form" },
}, { prefix = "g" })

-- vim-gh-line
wk.register({
  ["gb"] = { "Open blame view in browser" },
  ["gh"] = { "Open blob view in browser" },
  ["go"] = { "Open in browser" },
}, { prefix = "<leader>" })

-- wsdjeg/vim-fetch
wk.register({
  ["gF"] = { "Go to file:line under cursor" },
}, { mode = { "n", "x" } })
