" [Buffers] Jump to the existing window if possible
let g:fzf_buffers_jump = 1

" [Commands] --expect expression for directly executing the command
let g:fzf_commands_expect = 'alt-enter,ctrl-x'

command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number -- '.shellescape(<q-args>), 0,
  \   fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), <bang>0)

nnoremap <leader>ff :FZF<CR>

nmap <leader>fc :Commits<CR>
nmap <leader>fg :GFiles<CR>
nmap <leader>fG :GFiles?<CR>
nmap <leader>fh :History<CR>
nmap <leader>fr :Rg<CR>
nmap <leader>f: :History:<CR>
nmap <leader>f/ :History/<CR>

" Mapping selecting mappings
nmap <leader><tab> :call fzf#vim#commands({'options': [$FZF_DEFAULT_COLOR, '--no-preview']})<CR>
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

" Insert mode completion
imap <C-x><C-k> <plug>(fzf-complete-word)
imap <C-x><C-f> <plug>(fzf-complete-path)
imap <C-x><C-l> <plug>(fzf-complete-line)

