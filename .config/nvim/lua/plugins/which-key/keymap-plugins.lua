--- key bindings -------------------------------------------------------------------

local wk = require("which-key")
local m = require("mapx")

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
