"-- Inspiration: https://github.com/skwp/dotfiles/blob/master/vim/settings.vim

let vimsettings = '~/.vim/init/settings'

for fpath in split(globpath(vimsettings, '*.vim'), '\n')
  exe 'source' fpath
endfor
