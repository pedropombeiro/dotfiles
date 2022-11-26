--- key bindings -------------------------------------------------------------------

vim.cmd([[
noremap <C-q> :qa<CR>

nnoremap & :&&<CR>
xnoremap & :&&<CR>

noremap <leader>tn :tabnew<CR>
noremap <leader>tc :tabclose<CR>
noremap <leader>tt :tabs<CR>
nnoremap <C-s> :w<CR>
inoremap <C-s> <ESC>:w<CR>
nnoremap <C-q> :qa<CR>
inoremap <C-q> <ESC>:qa<CR>
" Switch between recently edited buffers (Mastering Vim Quickly)
  nnoremap <C-b> <C-^>
  inoremap <C-b> <ESC><C-^>

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

" Toggle showing special characters
nnoremap <leader>~ :<C-U>setlocal lcs=tab:>-,trail:-,eol:$ list! list? <CR>

" Map gp to select recently pasted text
" (https://vim.fandom.com/wiki/Selecting_your_pasted_text)
nnoremap <expr> gp '`[' . strpart(getregtype(), 0, 1) . '`]'

" ========================================
" General vim sanity improvements
" ========================================
"
"
" alias yw to yank the entire word 'yank inner word'
" even if the cursor is halfway inside the word
" FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
nnoremap <leader>yw yiww

" ,ow = 'overwrite word', replace a word with what's in the yank buffer
" FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
nnoremap <leader>ow "_diwhp

" ,# Surround a word with #{ruby interpolation}
map <leader># ysiw#
vmap <leader># c#{<C-R>"}<ESC>

" ," Surround a word with "quotes"
map <leader>" ysiW"
vmap <leader>" c"<C-R>""<ESC>

" ,' Surround a word with 'single quotes'
map <leader>' ysiW'
vmap <leader>' c'<C-R>"'<ESC>

" <leader>) or <leader>( Surround a word with (parens)
" The difference is in whether a space is put in
map <leader>( ysiw(
map <leader>) ysiw)
vmap <leader>( c( <C-R>" )<ESC>
vmap <leader>) c(<C-R>")<ESC>

" ,[ Surround a word with [brackets]
map <leader>] ysiw]
map <leader>[ ysiw[
vmap <leader>[ c[ <C-R>" ]<ESC>
vmap <leader>] c[<C-R>"]<ESC>

" <leader>{ Surround a word with {braces}
map <leader>} ysiw}
map <leader>{ ysiw{
vmap <leader>} c{ <C-R>" }<ESC>
vmap <leader>{ c{<C-R>"}<ESC>

map <leader>` ysiW`

nmap <leader>rf :Dispatch bundle exec rubocop --auto-correct %<CR>

nnoremap gv `[v`]
]])
