autocmd!

if has("nvim")
  " --- nvim-specific configuration
  source ~/.vim/init/nvim.vim
else
  " Avoid loading firenvim if not running on neovim, otherwise an error
  " message will popup. To that end, we just mark it as loaded already
  let g:firenvim_loaded=1
endif

source ~/.vim/init/plugins.vim
source ~/.vim/init/settings.vim
source ~/.vim/init/bindings.vim
source ~/.vim/init/coc.vim

" --- Plugin options

source ~/.vim/init/plugin-options.vim

if exists('g:started_by_firenvim')
  source ~/.vim/init/firenvim.vim
endif
