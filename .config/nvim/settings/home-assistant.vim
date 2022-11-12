augroup homeassistant
  autocmd BufRead,BufNewFile */config/home-assistant/*.yaml setlocal filetype=home-assistant syntax=yaml
  autocmd BufRead,BufNewFile */config/home-assistant/**/*.yaml setlocal filetype=home-assistant syntax=yaml
augroup END
