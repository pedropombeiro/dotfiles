if exists('g:started_by_firenvim')
  set guifont=MesloLGS\ Nerd\ Font:h22

  au BufEnter gitlab.com_*.txt set filetype=markdown

  " Never takeover by default
  let g:firenvim_config = {
      \ 'globalSettings': {
          \ 'alt': 'all',
      \  },
      \ 'localSettings': {
          \ '.*': {
              \ 'content': 'text',
              \ 'priority': 0,
              \ 'selector': 'textarea',
              \ 'takeover': 'never'
          \ },
      \ }
  \ }
endif
