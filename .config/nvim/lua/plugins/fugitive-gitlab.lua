-- fugitive-gitlab.vim (https://github.com/shumphrey/fugitive-gitlab.vim)
--  A vim extension to fugitive.vim for GitLab support

return {
  "shumphrey/fugitive-gitlab.vim",
  event = "VeryLazy",
  dependencies = "tpope/vim-fugitive",
  init = function()
    vim.cmd("command! -nargs=1 Browse silent execute '!open' shellescape(<q-args>,1)")
  end
}
