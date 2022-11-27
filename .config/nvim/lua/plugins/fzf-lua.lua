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

m.nname("<leader>f", "FZF")
m.nnoremap("<leader>ff", "<Cmd>FzfLua live_grep_native<CR>", "FZF")
m.nnoremap("<leader>fF", "<Cmd>FzfLua resume<CR>", "Resume last FZF command/query")
m.noremap("<leader><Tab>", "<Cmd>FzfLua keymaps<CR>", "Keymaps")
m.nnoremap("<leader>fb", "<Cmd>FzfLua buffers<CR>", "Buffers")
m.nnoremap("<leader>ft", "<Cmd>FzfLua tabs<CR>", "Tabs")
m.nnoremap("<leader>fc", "<Cmd>FzfLua git_commits<CR>", "Git commits")
m.nnoremap("<leader>fgg",
  "<Cmd>lua require('fzf-lua').live_grep({ prompt = 'GitGrep❯ ', cmd = 'git grep --line-number --column --color=always' })<CR>"
  , "Git grep")
m.nnoremap("<leader>fg", "<Cmd>FzfLua git_files<CR>", "Git files")
m.nnoremap("<leader>fG", "<Cmd>FzfLua git_status<CR>", "Git status")
m.nnoremap("<leader>fh", "<Cmd>FzfLua oldfiles<CR>", "Old files")
m.nnoremap("<leader>f:", "<Cmd>FzfLua command_history<CR>", "Command history")
m.nnoremap("<leader>f/", "<Cmd>FzfLua search_history<CR>", "Search history")
m.nnoremap({ "<leader>f`", "<leader>f'" }, "<Cmd>FzfLua marks<CR>", "Marks")
m.nnoremap("<leader>f.", "<Cmd>FzfLua jumps<CR>", "Jumps")
m.nnoremap("<leader>f@", "<Cmd>FzfLua registers<CR>", "Registers")
m.nnoremap("<leader>fr", "<Cmd>FzfLua grep<CR>", "Rg")
m.nnoremap("<leader>fs", "<Cmd>FzfLua lsp_live_workspace_symbols<CR>", "LSP workspace symbols")
