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
  nmap <silent> <leader>rv :TestVisit<CR>

  function! TestBranch()
    Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')
  endfunction
  nnoremap <leader>rb :call TestBranch()<CR>
endif
