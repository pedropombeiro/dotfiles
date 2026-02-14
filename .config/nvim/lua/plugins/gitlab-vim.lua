-- gitlab.vim (https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim)
--  GitLab Plugin for Neovim

return {
  "https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim.git",
  ft = { "go", "javascript", "python", "ruby" },
  cond = function() return vim.env.GITLAB_TOKEN ~= nil and vim.env.GITLAB_TOKEN ~= "" end,
  opts = {
    code_suggestions = {
      auto_filetypes = { "go", "javascript", "python", "ruby" },
    },
    resource_editing = {
      enabled = true,
    },
    statusline = {
      enabled = false,
    },
  },
}
