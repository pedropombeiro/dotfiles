-- fzf-lua (https://github.com/ibhagwan/fzf-lua)
--  Improved fzf.vim written in lua

require('fzf-lua').setup {
  fzf_opts = { ['--layout'] = 'reverse-list' },
}

local m = require('mapx').setup { global = "force", whichkey = true }

m.nname("<leader>f", "FZF")
m.nnoremap("<leader>ff", "<Cmd>lua require('fzf-lua').live_grep_native()<CR>", "FZF")
m.noremap("<leader><Tab>", "<Cmd>lua require('fzf-lua').keymaps()<CR>", "Keymaps")
m.nnoremap("<leader>fb", "<Cmd>lua require('fzf-lua').buffers()<CR>", "Buffers")
m.nnoremap("<leader>fw", "<Cmd>lua require('fzf-lua').windows()<CR>", "Windows")
m.nnoremap("<leader>fc", "<Cmd>lua require('fzf-lua').git_commits()<CR>", "Git commits")
m.nnoremap("<leader>fgg",
  "<Cmd>lua require('fzf-lua').live_grep({ prompt = 'GitGrep❯ ', cmd = 'git grep --line-number --column --color=always' })<CR>"
  , "Git grep")
m.nnoremap("<leader>fg", "<Cmd>lua require('fzf-lua').git_files()<CR>", "Git files")
m.nnoremap("<leader>fG", "<Cmd>lua require('fzf-lua').git_status()<CR>", "Git status")
m.nnoremap("<leader>fh", "<Cmd>lua require('fzf-lua').oldfiles()<CR>", "Old files")
m.nnoremap("<leader>f:", "<Cmd>lua require('fzf-lua').command_history()<CR>", "Command history")
m.nnoremap("<leader>f/", "<Cmd>lua require('fzf-lua').search_history()<CR>", "Search history")
m.nnoremap("<leader>fr", "<Cmd>lua require('fzf-lua').grep()<CR>", "Rg")
m.nnoremap("<leader>fs", "<Cmd>lua require('fzf-lua').lsp_live_workspace_symbols()<CR>", "LSP workspace symbols")
