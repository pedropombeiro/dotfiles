autocmd!

if ! has("nvim")
  " Avoid loading firenvim if not running on neovim, otherwise an error
  " message will popup. To that end, we just mark it as loaded already
  let g:firenvim_loaded=1
endif

" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

let mapleader = "\<Space>"
set timeoutlen=500

" Get the defaults that most users want.
if filereadable(expand("$VIMRUNTIME/defaults.vim"))
  source $VIMRUNTIME/defaults.vim
endif

source ~/.vim/init/plugins.vim
source ~/.vim/init/settings.vim
