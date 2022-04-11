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
set expandtab
set tabpagemax=40 " Max number of tab pages that can be opened from the command line
set noerrorbells
set confirm       " Display a confirmation dialog when closing a dirty buffer (Mastering Vim Quickly)

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

" netrw customization (https://shapeshed.com/vim-netrw/)
let g:netrw_liststyle=1 " wide view
let g:netrw_browse_split = 3
let g:netrw_altv = 1
let g:netrw_winsize = 25

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

" in makefiles, don't expand tabs to spaces, since actual tab characters are needed
autocmd FileType make set noexpandtab softtabstop=0

" --- show mode in cursor shape -------------------------------------------------------------------

let &t_SI = "\e[5 q"
let &t_EI = "\e[2 q"

