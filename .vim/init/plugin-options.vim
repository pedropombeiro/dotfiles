"-- FZF --

source ~/.vim/init/fzf.vim

"-- gruvbox theme --

autocmd vimenter * ++nested colorscheme gruvbox
let g:gruvbox_contrast_dark = 'hard'
let g:airline_theme = 'gruvbox'

"-- Git to Vim --

function! TabIsEmpty()
    return winnr('$') == 1 && len(expand('%')) == 0 && line2byte(line('$') + 1) <= 2
endfunction

function OpenBranchCommitedFiles()
  let parent_branch = trim(system("git show-branch --current | grep '\*' | grep -v `git rev-parse --abbrev-ref HEAD` | head -n1 | sed 's/[^[]*\\[\\([^]^]*\\).*\\].*/\\1/'"))
  let cmd = 'git diff --name-only ' . l:parent_branch . '...'
  let files = systemlist(l:cmd)
  let started_empty = TabIsEmpty()

  for f in l:files
    execute 'tabedit ' . l:f
  endfor
  if started_empty == 1
    execute '1tabclose'
  endif
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

  function! TestBranch()
    Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')
  endfunction
  nnoremap <leader>ra :call TestBranch<CR>
endif

"-- vim-rails.vim
nnoremap <leader>ga :R<CR>

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
let g:airline#extensions#tabline#enabled = 1


"-- EditorConfig
let g:editorconfig_blacklist = {
    \ 'filetype': ['git.*', 'fugitive'],
    \ 'pattern': ['\.un~$', 'scp://.*']}
let g:editorconfig_root_chdir = 1

"-- Illuminate
let g:Illuminate_ftblacklist = ['nerdtree']

"-- LazyGit
" setup mapping to call :LazyGit
nnoremap <silent> <leader>gg :LazyGit<CR>
