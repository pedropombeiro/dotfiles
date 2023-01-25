-- fugitive-gitlab.vim (https://github.com/shumphrey/fugitive-gitlab.vim)
--  A vim extension to fugitive.vim for GitLab support

return {
  "shumphrey/fugitive-gitlab.vim",
  cmd = "GBrowse",
  keys = {
    "<C-X><C-O>"
  },
  dependencies = "tpope/vim-fugitive"
}
