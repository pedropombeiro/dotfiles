" Use current nvim instance as the preferred text editor (Moderm Vim)
if executable('nvr')
  let $VISUAL="nvr -cc split --remote-wait +'set bufhidden=wipe'"
endif