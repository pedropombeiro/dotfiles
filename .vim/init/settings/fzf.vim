unlet $FZF_DEFAULT_OPTS " Remove default opts which hide the preview window, since the Ctrl-/ keystroke does not get correctly interpreted in Neovim. This way we can also decide the best preview for each command
unlet $FZF_PREVIEW_COMMAND

" [Buffers] Jump to the existing window if possible
let g:fzf_buffers_jump = 1

" [Commands] --expect expression for directly executing the command
let g:fzf_commands_expect = 'alt-enter,ctrl-x'

let s:_fzf_opts = ['--height=40%', '--inline-info', '--border', '--ansi', '--preview', '~/.vim/plugged/fzf.vim/bin/preview.sh {}']
" Customize with gruvbox colors
let s:_fzf_opts = add(s:_fzf_opts, '--color=bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934')

command! -bang -nargs=? -complete=dir Files
    \ call fzf#vim#files(<q-args>, {'options': s:_fzf_opts}, <bang>0)

command! -bang -nargs=? -complete=dir History
    \ call fzf#vim#history({'options': s:_fzf_opts}, <bang>0)

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
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

" Insert mode completion
imap <C-x><C-k> <plug>(fzf-complete-word)
imap <C-x><C-f> <plug>(fzf-complete-path)
imap <C-x><C-l> <plug>(fzf-complete-line)

