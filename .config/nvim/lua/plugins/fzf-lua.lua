-- fzf-lua (https://github.com/ibhagwan/fzf-lua)
--  Improved fzf.vim written in lua

require("fzf-lua").setup {
  winopts = {
    preview = {
      layout = "vertical",
    },
  },
}

local m = require("mapx").setup { global = "force", whichkey = true }

m.nname("f", "FZF")
m.nnoremap("ff", "<Cmd>FzfLua live_grep_native<CR>", "Live grep (rg)")
m.nnoremap("fF", "<Cmd>FzfLua resume<CR>", "Resume last FZF command/query")
m.noremap("<leader><Tab>", "<Cmd>FzfLua keymaps<CR>", "Keymaps")
m.nnoremap("fb", "<Cmd>FzfLua buffers<CR>", "Buffers")
m.nnoremap("fc", "<Cmd>FzfLua colorschemes<CR>", "Colorschemes")
m.nnoremap("fK", "<Cmd>FzfLua man_pages<CR>", "Man pages")
m.nnoremap("fl", "<Cmd>FzfLua loclist<CR>", "Location list")
m.nnoremap("fq", "<Cmd>FzfLua quickfix<CR>", "Quickfix list")
m.nnoremap("ft", "<Cmd>FzfLua tabs<CR>", "Tabs")
m.nnoremap("fT", "<Cmd>FzfLua filetypes<CR>", "Filetypes")
m.nnoremap("fh", "<Cmd>FzfLua oldfiles<CR>", "Old files")
m.nnoremap("f:", "<Cmd>FzfLua command_history<CR>", "Command history")
m.nnoremap("f/", "<Cmd>FzfLua search_history<CR>", "Search history")
m.nnoremap({ "f`", "f'" }, "<Cmd>FzfLua marks<CR>", "Marks")
m.nnoremap("f.", "<Cmd>FzfLua jumps<CR>", "Jump list")
m.nnoremap("f@", "<Cmd>FzfLua registers<CR>", "Registers")
m.nnoremap("fs", "<Cmd>FzfLua spell_suggest<CR>", "Spelling suggestions")

m.nname("fg", "FZF (Git)")
m.nnoremap("fgb", "<Cmd>FzfLua git_branches<CR>", "Git branches")
m.nnoremap("fgc", "<Cmd>FzfLua git_commits<CR>", "Git commits")
m.nnoremap("fgC", "<Cmd>FzfLua git_bcommits<CR>", "Git commits (buffer)")
m.nnoremap("fgg",
  function()
    require('fzf-lua').live_grep({ prompt = 'GitGrep❯ ', cmd = 'git grep --line-number --column --color=always' })
  end, "Git grep")
m.nnoremap("fgf", "<Cmd>FzfLua git_files<CR>", "Git files")
m.nnoremap("fgs", "<Cmd>FzfLua git_status<CR>", "Git status")
m.nnoremap("fgS", "<Cmd>FzfLua git_stash<CR>", "Git stash")

m.nname("<leader>l", "FZF (LSP)")
m.nname("<leader>lc", "FZF (LSP code actions)")
m.nnoremap("<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>", "Code actions")
m.nnoremap("<leader>ls", "<Cmd>FzfLua lsp_document_symbols<CR>", "Document symbols")
m.nnoremap("<leader>lr", "<Cmd>FzfLua lsp_references<CR>", "References")
m.nnoremap({ "<leader>ld", "<C-]>" }, "<Cmd>FzfLua lsp_definitions<CR>", "Definitions")
m.nnoremap("<leader>lt", "<Cmd>FzfLua lsp_typedefs<CR>", "Typedefs")
m.nnoremap("<leader>lws", "<Cmd>FzfLua lsp_live_workspace_symbols<CR>", "Workspace symbols")
