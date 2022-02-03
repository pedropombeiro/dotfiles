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

