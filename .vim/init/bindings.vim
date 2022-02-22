" --- key bindings -------------------------------------------------------------------

set pastetoggle=<f5>
let mapleader = "\<Space>"

noremap <C-q> :qa<CR>

nnoremap & :&&<CR>
xnoremap & :&&<CR>

noremap <leader>nt :tabnew<CR>
noremap <leader>ct :tabclose<CR>
noremap <leader>tt :tabs<CR>
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

" -- Toggle netrw pane
"  (https://www.reddit.com/r/vim/comments/6jcyfj/toggle_lexplore_properly/djdmsal/)
let g:NetrwIsOpen=0

function! ToggleNetrw()
    if g:NetrwIsOpen
        let i = bufnr("$")
        while (i >= 1)
            if (getbufvar(i, "&filetype") == "netrw")
                silent exe "bwipeout " . i
            endif
            let i-=1
        endwhile
        let g:NetrwIsOpen=0
    else
        let g:NetrwIsOpen=1
        silent Lexplore
    endif
endfunction

nnoremap <silent> <C-\> :call ToggleNetrw()<CR>
vnoremap <silent> <C-\> :call ToggleNetrw()<CR>

