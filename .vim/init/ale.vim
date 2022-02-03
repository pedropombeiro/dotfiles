" --- ALE ------------------------------------------------------------------

let g:airline#extensions#ale#enabled = 1
let g:ale_lint_delay=1000

" Enable completion where available.
" This setting must be set before ALE is loaded.
"
" You should not turn this setting on if you wish to use ALE as a completion
" source for other completion plugins, like Deoplete.
let g:ale_completion_enabled = 1

function ALELSPMappings()
  let lsp_found=0
  for linter in ale#linter#Get(&filetype)
    if !empty(linter.lsp) && ale#lsp_linter#CheckWithLSP(bufnr(''), linter)
      let lsp_found=1
    endif
  endfor
  if (lsp_found)
    nnoremap <buffer> K     :ALEDocumentation<CR>
    nnoremap <buffer> <C-]> :ALEGoToDefinition<CR>
    nnoremap <buffer> <C-^> :ALEFindReferences<CR>
    nnoremap <buffer> gr    :ALEFindReferences<CR>
    nnoremap <buffer> gd    :ALEGoToDefinition<CR>
    nnoremap <buffer> gy    :ALEGoToTypeDefinition<CR>
    nnoremap <buffer> gh    :ALEHover<CR>
    nnoremap <buffer> <f2>  :ALERename<CR>

    nmap <silent> <C-k> <Plug>(ale_previous_wrap)
    nmap <silent> <C-j> <Plug>(ale_next_wrap)

    setlocal omnifunc=ale#completion#OmniFunc

    let g:ale_ruby_rubocop_options = '--parallel'
  endif
endfunction
autocmd BufRead,FileType * call ALELSPMappings()

