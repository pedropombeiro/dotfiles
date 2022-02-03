source ~/.vim/init/fzf.vim

"-- Git to Vim --

function OpenBranchCommitedFiles()
  if !empty(glob(".git/refs/heads/master"))
    args `git diff --name-only master...`
  else
    args `git diff --name-only main...`
  endif
  tab all
endfunction

:command Branch call OpenBranchCommitedFiles()

:nnoremap <leader>ob :Branch<ESC>

"-- GitGutter --
let g:gitgutter_enabled              = 1
let g:gitgutter_realtime             = 0
let g:gitgutter_eager                = 0
let g:gitgutter_set_sign_backgrounds = 1
let g:gitgutter_highlight_linenrs    = 1
let g:gitgutter_grep                 = 'grep -e'

"-- vim-test
let test#strategy = {
      \ 'nearest': 'asyncrun_background',
      \ 'file':    'dispatch',
      \ 'suite':   'dispatch',
      \}
if !empty($GDK_ROOT)
  nmap <silent> <leader>rt :TestNearest<CR>
  nmap <silent> <leader>rT :TestFile<CR>
  nmap <silent> <leader>ra :TestSuite<CR>
  nmap <silent> <leader>rl :TestLast<CR>
  nmap <silent> <leader>g  :TestVisit<CR>
endif

"-- vim-rails.vim
if !empty($GDK_ROOT)
  nnoremap <C-S-t> :R<CR>
endif

"-- EasyAlign
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

"-- indent-guides
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_exclude_filetypes     = ['help', 'nerdtree', 'man']
let g:indent_guides_default_mapping       = 0
let g:indent_guides_guide_size            = 1

"-- vim-airline
let g:airline_powerline_fonts = 1

"-- EditorConfig
let g:editorconfig_blacklist = {
    \ 'filetype': ['git.*', 'fugitive'],
    \ 'pattern': ['\.un~$', 'scp://.*']}
let g:editorconfig_root_chdir = 1

"-- Illuminate
let g:Illuminate_ftblacklist = ['nerdtree']

