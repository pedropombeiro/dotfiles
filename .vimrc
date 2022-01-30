autocmd!

" Get the defaults that most users want.
if filereadable(expand("$VIMRUNTIME/defaults.vim"))
  source $VIMRUNTIME/defaults.vim
endif

" === options ==================================================================

set nocompatible  " vim settings
set nomodeline    " security measure
set shortmess+=I
set noswapfile    " disable the swapfile
set history=2000
set updatetime=1000
set wildmenu      " set zsh-alike autocomplete behavior
set wildmode=full
set tabpagemax=40 " Max number of tab pages that can be opened from the command line
set noerrorbells
set confirm       " Display a confirmation dialog when closing a dirty buffer (Mastering Vim Quickly)

"" enable project-specific vimrc (dangerous if editing unvetted files)
"set exrc
"set secure

if !has("nvim")
  set undodir=$HOME/.vim/undodir " (Mastering Vim Quickly)
endif
set undofile
augroup vimrc_undofile " (Modern Vim)
  autocmd!
  autocmd BufWritePre /tmp/* setlocal noundofile
augroup END

set spell spelllang=en_us
set nospell

" Relative line number (Mastering Vim Quickly)
set relativenumber
augroup toggle_relative_number
  au!
  autocmd InsertEnter * :setlocal norelativenumber
  autocmd InsertLeave * :setlocal relativenumber
augroup END

" Q: Mouse reporting in vim doesn't work for some rows/columns in a big terminal window.
if has('mouse_sgr')
  set ttymouse=sgr
endif

syntax enable

"" Use the OS clipboard
"set clipboard=unnamed

" allow buffer switching without saving
set hidden

" Make macros render faster (lazy draw)
set lazyredraw

let g:netrw_liststyle=1 " wide view

" --- theming -------------------------------------------------------------------

set cursorline
set background=dark
if has("termguicolors")
  set termguicolors
endif

"colorscheme solarized

highlight CursorLine      ctermfg=NONE        guifg=NONE        ctermbg=DarkGray    guibg=#0F0F0F
highlight LineNr          ctermfg=DarkGray    guifg=#777777

" --- layout -------------------------------------------------------------------

set notitle      " change terms title
set number       " show line numbers
set ruler        " show ruler in status line
set showmode     " always show mode
set laststatus=2 " always show status line
set showcmd      " show the command being typed
set scrolloff=4  " keep 4 lines off the edges
set pumheight=10 " popup menu height

set foldmethod=syntax
set foldlevelstart=99

let $GIT_CONFIG_PARAMETERS="'delta.side-by-side=false'" " Disable .gitconfig's delta option

" --- search -------------------------------------------------------------------

set incsearch
set ignorecase
set smartcase
set hlsearch

" --- format -------------------------------------------------------------------

set encoding=utf-8
set termencoding=utf-8
set fileformats=unix,dos,mac " supported formats
set nobomb                   " don't use a BOM
set shiftwidth=2
set softtabstop=2
set tabstop=2

filetype on
filetype plugin on
filetype indent on
syntax on

match ErrorMsg '\s\+$'               " highlight trailing whitespace (Mastering Vim Quickly)
autocmd BufWritePre * :%s/\s\+$//e   " remove trailing whitespace automatically on save (Mastering Vim Quickly)
if has("nvim")
  autocmd TermOpen * match none      " clear the highlighting if we're a terminal buffer
else
  autocmd TerminalOpen * match none  " clear the highlighting if we're a terminal buffer
endif

" --- key bindings -------------------------------------------------------------------

set pastetoggle=<f5>
let mapleader = "\<Space>"

inoremap jk <ESC>

nnoremap & :&&<CR>
xnoremap & :&&<CR>

noremap <leader>nt :tabnew<CR>
noremap <leader>ct :tabclose<CR>
nnoremap <C-s> :w<CR>
inoremap <C-s> <ESC>:w<CR>
nnoremap <C-q> :qa<CR>
inoremap <C-q> <ESC>:qa<CR>
" Switch between recently edited buffers (Mastering Vim Quickly)
  nnoremap <C-b> <C-^>
  inoremap <C-b> <ESC><C-^>

nnoremap <leader>f :FZF<CR>

" Map Esc to normal mode in terminal mode
tnoremap <leader><ESC> <C-\><C-n>

" make . work with visually selected lines
vnoremap . :normal.<CR>

" Center next/previous matches on the screen (Mastering Vim Quickly)
nnoremap n nzz
nnoremap N Nzz

" -- Move lines with single key combo (Mastering Vim Quickly)
  " Normal mode
  nnoremap <C-j> :m .+1<CR>==
  nnoremap <C-k> :m .-2<CR>==

  " Insert mode
  inoremap <C-j> <ESC>:m .+1<CR>==gi
  inoremap <C-k> <ESC>:m .-2<CR>==gi

  " Visual mode
  vnoremap <C-j> :m '>+1<CR>gv=gv
  vnoremap <C-k> :m '<-2<CR>gv=gv

" --- nvim-specific configuration

if has("nvim")
  " Use current nvim instance as the preferred text editor (Moderm Vim)
  if executable('nvr')
    let $VISUAL="nvr -cc split --remote-wait +'set bufhidden=wipe'"
  endif
endif

" --- show mode in cursor shape -------------------------------------------------------------------

let &t_SI = "\e[5 q"
let &t_EI = "\e[2 q"

" --- ALE ------------------------------------------------------------------

let g:airline#extensions#ale#enabled = 1
let g:ale_lint_delay=1000

" Enable completion where available.
" This setting must be set before ALE is loaded.
"
" You should not turn this setting on if you wish to use ALE as a completion
" source for other completion plugins, like Deoplete.
let g:ale_completion_enabled = 1

function ALELSPMappings()
  let lsp_found=0
  for linter in ale#linter#Get(&filetype)
    if !empty(linter.lsp) && ale#lsp_linter#CheckWithLSP(bufnr(''), linter)
      let lsp_found=1
    endif
  endfor
  if (lsp_found)
    nnoremap <buffer> K     :ALEDocumentation<CR>
    nnoremap <buffer> <C-]> :ALEGoToDefinition<CR>
    nnoremap <buffer> <C-^> :ALEFindReferences<CR>
    nnoremap <buffer> gr    :ALEFindReferences<CR>
    nnoremap <buffer> gd    :ALEGoToDefinition<CR>
    nnoremap <buffer> gy    :ALEGoToTypeDefinition<CR>
    nnoremap <buffer> gh    :ALEHover<CR>
    nnoremap <buffer> <f2>  :ALERename<CR>

    nmap <silent> <C-k> <Plug>(ale_previous_wrap)
    nmap <silent> <C-j> <Plug>(ale_next_wrap)

    setlocal omnifunc=ale#completion#OmniFunc

    let g:ale_ruby_rubocop_options = '--parallel'
  endif
endfunction
autocmd BufRead,FileType * call ALELSPMappings()

"-- NERDTree --
let NERDTreeShowHidden=1

" calls NERDTreeFind iff NERDTree is active, current window contains a modifiable file, and we're not in vimdiff
function! s:syncTree()
  if (&diff == 1) " Exit if in diff mode
    return
  endif

  let s:curwnum = winnr()
  let s:winFileType = getwinvar(s:curwnum, '&filetype')
  if (s:winFileType == 'man') " Exit if viewing a man page
    return
  endif

  NERDTreeFind
  exec s:curwnum . "wincmd w"
endfunction

function! s:syncTreeIf()
  if (winnr("$") > 1)
    call s:syncTree()
  endif
endfunction

function! s:syncTreeIfNotEmpty()
  if (argc() > 0)
    call s:syncTree()
    wincmd w
  endif
endfunction

" Show/Hide NERDTree
nmap <expr> \a (winnr("$") == 1) ? ':NERDTreeFind<CR>' : ':wincmd o<CR>'

if has("autocmd")
  augroup nerdtree_customizations
    " Clear all autocmds
    autocmd!

    " Prevent Tab on NERDTree (breaks everything otherwise)
    autocmd FileType nerdtree noremap <buffer> <Tab> <nop>

    " Focus on opened view after starting (instead of NERDTree)
    autocmd VimEnter * call s:syncTreeIfNotEmpty()

    " Prevent this command activation in NERDTree
    autocmd FileType nerdtree noremap <buffer> \a <nop>

    " Start NERDTree when Vim starts with a directory argument.
    autocmd StdinReadPre * let s:std_in=1
    autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
          \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif

    " If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
    autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
          \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif

    " Exit Vim if NERDTree is the only window remaining in the only tab.
    autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
  augroup END
endif

nnoremap <C-bslash> :NERDTreeToggle<CR>

" Switch between NERDTree and opened file
:nmap \e :wincmd w<CR>
" Mirror the NERDTree before showing it. This makes it the same on all tabs.
nnoremap <C-bslash> :NERDTreeMirror<CR>:NERDTreeToggle<CR>

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

"-- FZF
let g:fzf_buffers_jump = 1

nmap <leader>fc :Commits<CR>
nmap <leader>fg :GFiles<CR>
nmap <leader>fG :GFiles?<CR>
nmap <leader>fh :History<CR>
nmap <leader>fr :Rg<CR>
nmap <leader>f: :History:<CR>
nmap <leader>f/ :History/<CR>

" Mapping selecting mappings
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

" Insert mode completion
imap <C-x><C-k> <plug>(fzf-complete-word)
imap <C-x><C-f> <plug>(fzf-complete-path)
imap <C-x><C-l> <plug>(fzf-complete-line)

"-- EditorConfig
let g:editorconfig_blacklist = {
    \ 'filetype': ['git.*', 'fugitive'],
    \ 'pattern': ['\.un~$', 'scp://.*']}
let g:editorconfig_root_chdir = 1

"-- Illuminate
let g:Illuminate_ftblacklist = ['nerdtree']

