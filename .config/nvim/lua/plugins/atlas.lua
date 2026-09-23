-- atlas.nvim (https://github.com/emrearmagan/atlas.nvim)
--   Review pull requests and manage issues from Neovim.

return {
  "emrearmagan/atlas.nvim",
  dependencies = {
    "kyazdani42/nvim-web-devicons",
    "meanderingprogrammer/render-markdown.nvim",
  },
  cmd = { "Atlas", "AtlasDiff" },
  ---@module "lazy"
  ---@type LazyKeysSpec[]
  keys = {
    { "<leader>mm", "<cmd>Atlas<cr>", desc = "Atlas" },
    { "<leader>mp", "<cmd>Atlas pulls<cr>", desc = "Pull requests" },
    { "<leader>mi", "<cmd>Atlas issues<cr>", desc = "Issues" },
    { "<leader>mr", "<cmd>Atlas review<cr>", desc = "Review pull request" },
    { "<leader>mc", "<cmd>Atlas create<cr>", desc = "Create pull request or issue" },
    { "<leader>ms", "<cmd>Atlas search<cr>", desc = "Search pull requests and issues" },
  },
  ---@module "atlas"
  ---@return AtlasConfig
  opts = function()
    local token = ""
    if vim.fn.executable("glab") == 1 then
      local out = vim.fn.system({ "glab", "config", "get", "token", "--host", "gitlab.com" })
      if vim.v.shell_error == 0 then token = vim.trim(out) end
    end

    return {
      providers = {
        github = {},
        gitlab = {
          base_url = "https://gitlab.com",
          token = token,
        },
      },
      pulls = {
        diff = {
          open_cmd = "AtlasDiff",
          layout = "inline",
          compact = true,
        },
        gitlab = {
          views = {
            { name = "Reviewing", key = "1", scope = "reviews_for_me" },
            { name = "Assigned", key = "2", scope = "assigned_to_me" },
            { name = "Created", key = "3", scope = "created_by_me" },
          },
        },
        github = {
          views = {
            { name = "My PRs", key = "4", search = "author:@me sort:updated-desc" },
            { name = "Review requested", key = "5", search = "review-requested:@me sort:updated-desc" },
          },
        },
      },
      issues = {
        gitlab = {
          views = {
            { name = "Assigned", key = "1", scope = "assigned_to_me", state = "opened" },
            { name = "Created", key = "2", scope = "created_by_me", state = "opened" },
          },
        },
        github = {
          views = {
            { name = "Assigned", key = "3", search = "assignee:@me is:open" },
          },
        },
      },
    }
  end,
}
