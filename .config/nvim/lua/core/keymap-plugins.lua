--- key bindings -------------------------------------------------------------------

local wk = require("which-key")
local m = require("mapx").setup { global = "force", whichkey = true }
local silent = { silent = true }

-- vim-commentary
m.nname("<leader>c", "Commentary")

-- DAP
m.nnoremap("<S-F5>", function() require("dap").close() end, "Close DAP")
m.nnoremap("<F5>", function() require("dap").continue() end, "Continue execution")
m.nnoremap("<F7>", function() require("dap").step_into() end, "Step into")
m.nnoremap("<F8>", function() require("dap").step_over() end, "Step over")
m.nnoremap("<F9>", function() require("dap").toggle_breakpoint() end, "Toggle breakpoint")
m.nname("<leader>d", "Debug")
m.nnoremap("<leader>dl", function() require("dap-go").debug_last_test() end, { ft = "go" }, "Debug last Go test")
m.nnoremap("<leader>dt", function() require("dap-go").debug_test() end, { ft = "go" }, "Debug Go test")
m.nnoremap("<leader>rl", function() require("dap-go").run_last() end, { ft = "go" }, "Run last Go test")

-- DAP UI
m.vnoremap("<leader>de", function() require("dapui").eval() end, silent, "Evaluate with DAP")
m.nnoremap("<leader>dui", function() require("dapui").toggle() end, silent, "Toggle DAP UI")
m.nnoremap("<leader>dro", function() require("dap").repl.open() end, silent, "Open REPL")

-- vim-easy-align (https://github.com/junegunn/vim-easy-align)
--- Start interactive EasyAlign in visual mode (e.g. vipga) and for a motion/text object (e.g. gaip)
m.nnoremap("ga", "<Plug>(EasyAlign)", silent, "Easy Align")
m.xnoremap("ga", "<Plug>(EasyAlign)", silent, "Easy Align")

-- LazyGit
local function openLazyGit()
  if vim.env.GIT_DIR == vim.fn.expand("~/.local/share/yadm/repo.git") then
    -- Ensure that we're located at the repository root, so that LazyGit correctly displays diffs
    vim.cmd("cd ~")
  end
  vim.cmd("LazyGit")
end

m.nnoremap("<leader>gg", openLazyGit, silent, "Open LazyGit")
m.nnoremap("<leader>gf", ":LazyGitFilter<CR>", "Open LazyGit for current buffer")

-- nvim-code-action-menu.vim (https://github.com/weilbith/nvim-code-action-menu)
m.nnoremap("<leader>la", ":CodeActionMenu<CR>", silent, "Open code action menu")

-- Ranger
m.nnoremap("<leader>R", ":Ranger<CR>", "Open Ranger")

-- Splitjoin.vim
wk.register({
  S = { "Split into multi-line form" },
  J = { "Join into single-line form" },
}, { prefix = "g" })

-- symbols-outline
m.nnoremap("<C-'>", ":SymbolsOutline<CR>", "Toggle symbols window")
m.vnoremap("<C-'>", ":SymbolsOutline<CR>", "Toggle symbols window")

-- vim-gh-line
wk.register({
  ["gb"] = { "Open blame view in browser" },
  ["gh"] = { "Open blob view in browser" },
  ["go"] = { "Open in browser" },
}, { prefix = "<leader>" })

-- vim-unimpaired
m.nname("=", "Unimpaired")
