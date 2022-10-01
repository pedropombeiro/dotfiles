if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1 " Don't load twice in one buffer

" Automatically wrap at 72 characters and spell check commit messages
autocmd BufNewFile,BufRead PULLREQ_EDITMSG set syntax=gitcommit
setlocal textwidth=72
setlocal spell
