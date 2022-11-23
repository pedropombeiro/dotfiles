-- w!! to write a file as sudo
-- stolen from Steve Losh
vim.keymap.set("c", "w!!", ":w ! sudo tee % > /dev/null")
