"-- Ranger
let g:ranger_map_keys = 0
map <leader>R :Ranger<CR>

if has("nvim")
  autocmd TermOpen * :IndentGuidesDisable
  autocmd TermClose * :IndentGuidesEnable
else
  autocmd TerminalWinOpen * :IndentGuidesDisable
  autocmd WinClosed terminal :IndentGuidesEnable
endif

