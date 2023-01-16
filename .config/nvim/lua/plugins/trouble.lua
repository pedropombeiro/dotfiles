-- trouble.nvim (https://github.com/folke/trouble.nvim)
-- 🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve
--  all the trouble your code is causing.

local m = require("mapx").setup { global = "force", whichkey = true }
local opts = { silent = true }

m.nname("<leader>x", "Trouble 🚦")
m.nnoremap("<leader>xx", "<cmd>TroubleToggle<cr>", opts, "Toggle Trouble window")
m.nnoremap("<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", opts, "Toggle workspace diagnostics")
m.nnoremap("<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", opts, "Toggle document diagnostics")
m.nnoremap("<leader>xq", "<cmd>TroubleToggle quickfix<cr>", opts, "Toggle quickfix window")
m.nnoremap("<leader>xl", "<cmd>TroubleToggle loclist<cr>", opts, "Toggle loclist window")
