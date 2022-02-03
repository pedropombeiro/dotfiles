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

