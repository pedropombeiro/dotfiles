-- gitlab.vim (https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim)
--  GitLab Plugin for Neovim

return {
  'git@gitlab.com:gitlab-org/editor-extensions/gitlab.vim.git',
  ft = { 'go', 'javascript', 'python', 'ruby' },
  cond = function()
    return vim.env.GITLAB_TOKEN ~= nil and vim.env.GITLAB_TOKEN ~= ''
  end,
  opts = {
    statusline = {
      enabled = false,
    },
  },
}
