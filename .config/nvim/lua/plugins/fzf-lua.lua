-- fzf-lua (https://github.com/ibhagwan/fzf-lua)
--  Improved fzf.vim written in lua

local fzf = require("fzf-lua")
fzf.setup {
  winopts = {
    preview = {
      layout = "vertical",
    },
  },
}

local m = require("mapx").setup { global = "force", whichkey = true }

m.nname("<leader>f", "FZF")
m.nnoremap("<leader>ff", "<Cmd>FzfLua live_grep_native<CR>", "Live grep (rg)")
m.nnoremap("<leader>fF", "<Cmd>FzfLua resume<CR>", "Resume last FZF command/query")
m.noremap("<leader><Tab>", "<Cmd>FzfLua keymaps<CR>", "Keymaps")
m.nnoremap("<leader>fb", "<Cmd>FzfLua buffers<CR>", "Buffers")
m.nnoremap("<leader>fc", "<Cmd>FzfLua colorschemes<CR>", "Colorschemes")
m.nnoremap("<leader>fK", "<Cmd>FzfLua man_pages<CR>", "Man pages")
m.nnoremap("<leader>fl", "<Cmd>FzfLua loclist<CR>", "Location list")
m.nnoremap("<leader>fq", "<Cmd>FzfLua quickfix<CR>", "Quickfix list")
m.nnoremap("<leader>ft", "<Cmd>FzfLua tabs<CR>", "Tabs")
m.nnoremap("<leader>fT", "<Cmd>FzfLua filetypes<CR>", "Filetypes")
m.nnoremap("<leader>fh", "<Cmd>FzfLua oldfiles<CR>", "Old files")
m.nnoremap("<leader>f:", "<Cmd>FzfLua command_history<CR>", "Command history")
m.nnoremap("<leader>f/", "<Cmd>FzfLua search_history<CR>", "Search history")
m.nnoremap({ "<leader>f`", "<leader>f'" }, "<Cmd>FzfLua marks<CR>", "Marks")
m.nnoremap("<leader>f.", "<Cmd>FzfLua jumps<CR>", "Jump list")
m.nnoremap("<leader>f@", "<Cmd>FzfLua registers<CR>", "Registers")
m.nnoremap("<leader>fs", "<Cmd>FzfLua spell_suggest<CR>", "Spelling suggestions")

m.nname("<leader>fg", "FZF (Git)")
m.nnoremap("<leader>fgb", "<Cmd>FzfLua git_branches<CR>", "Git branches")
m.nnoremap("<leader>fgc", "<Cmd>FzfLua git_commits<CR>", "Git commits")
m.nnoremap("<leader>fgC", "<Cmd>FzfLua git_bcommits<CR>", "Git commits (buffer)")
m.nnoremap("<leader>fgg",
  function()
    require("fzf-lua").live_grep({ prompt = "GitGrep❯ ", cmd = "git grep --line-number --column --color=always" })
  end, "Git grep")
m.nnoremap("<leader>fgf", "<Cmd>FzfLua git_files<CR>", "Git files")
m.nnoremap("<leader>fgs", "<Cmd>FzfLua git_status<CR>", "Git status")
m.nnoremap("<leader>fgS", "<Cmd>FzfLua git_stash<CR>", "Git stash")

m.nname("<leader>l", "FZF (LSP)")
m.nnoremap("<leader>ls", "<Cmd>FzfLua lsp_document_symbols<CR>", "Document symbols")
m.nnoremap("<leader>lr", "<Cmd>FzfLua lsp_references<CR>", "References")
m.nnoremap({ "<leader>ld", "<C-]>" }, "<Cmd>FzfLua lsp_definitions<CR>", "Definitions")
m.nnoremap("<leader>lt", "<Cmd>FzfLua lsp_typedefs<CR>", "Typedefs")
m.nnoremap("<leader>lws", "<Cmd>FzfLua lsp_live_workspace_symbols<CR>", "Workspace symbols")
m.nname("<leader>lc", "FZF (LSP code actions)")
m.nnoremap("<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>", "Code actions")

fzf.register_ui_select() -- register fzf-lua as the UI interface for vim.ui.select
