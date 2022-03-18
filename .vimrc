autocmd!

if has("nvim")
  " --- nvim-specific configuration
  source ~/.vim/init/nvim.vim
endif

source ~/.vim/init/settings.vim
source ~/.vim/init/bindings.vim
source ~/.vim/init/ale.vim

" --- Plugin options

source ~/.vim/init/plugin-options.vim

if exists('g:started_by_firenvim')
  source ~/.vim/init/firenvim.vim
endif
