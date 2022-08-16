nnoremap <silent> <leader> :WhichKey '<Space>'<CR>
nnoremap <silent> g :WhichKey 'g'<CR>
nnoremap <silent> [ :WhichKey '['<CR>
nnoremap <silent> ] :WhichKey ']'<CR>

" Hide statusline
autocmd! FileType which_key
autocmd  FileType which_key set laststatus=0 noshowmode noruler
  \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler

let g:which_key_map = {}
let g:which_key_map.c = { 'name' : '+commenter/coc' }
let g:which_key_map.f = { 'name' : '+find' }
let g:which_key_map.f.c = 'Search commits'
let g:which_key_map.f.g = 'Search git files'
let g:which_key_map.f.G = 'Search git status'
let g:which_key_map.f.h = 'Search history'
let g:which_key_map.f.f = 'Open FZF window'
let g:which_key_map.f.r = 'rg search result'
let g:which_key_map.h = { 'name' : '+hunk' }
let g:which_key_map.r = { 'name' : '+test' }
let g:which_key_map.r.b = 'Run tests (current buffer)'
let g:which_key_map.r.l = 'Repeat test run'
let g:which_key_map.r.t = 'Run spec under cursor'
let g:which_key_map.r.T = 'Run tests (current file)'
let g:which_key_map.r.f = 'Format with Rubocop'
let g:which_key_map.t = { 'name' : '+tab' }
let g:which_key_map.t.c = 'Close tab'
let g:which_key_map.t.n = 'New tab'
let g:which_key_map.t.t = 'Tabs list'
let g:which_key_map.g = { 'name' : '+go' }
let g:which_key_map.g.a = 'Alternate'
let g:which_key_map.g.b = 'Line blame'
let g:which_key_map.g.h = 'Git line'
let g:which_key_map.g.o = 'Git repo'
let g:which_key_map.g.r = 'Related (EE/non-EE)'
let g:which_key_map.y = { 'name' : '+yank' }

let g:which_key_map_g =  {}
let g:which_key_map_g.c = { 'name' : 'which_key_ignore' }
let g:which_key_map_g.cc = 'Comment line'
let g:which_key_map_g.cu = 'Uncomment line'
let g:which_key_map_g.F = 'Go to file (vim-fetch)'
let g:which_key_map_g.p = 'Select previous block'
let g:which_key_map_g.J = 'Join line'
let g:which_key_map_g.S = 'Split line'

let g:which_key_exit = ["\<C-q>", "\<C-[>", "\<Esc>"]
" Executes native commands if keymap is not defined (makes gg work correctly)
let g:which_key_fallback_to_native_key=1

call which_key#register('<Space>', "g:which_key_map")
call which_key#register('g', "g:which_key_map_g")

