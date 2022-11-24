-- fugitive-gitlab.vim (https://github.com/shumphrey/fugitive-gitlab.vim)
--  A vim extension to fugitive.vim for GitLab support

vim.cmd("command! -nargs=1 Browse silent execute '!open' shellescape(<q-args>,1)")
