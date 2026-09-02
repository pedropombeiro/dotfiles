-- overseer.nvim (https://github.com/stevearc/overseer.nvim)
--  A task runner and job management plugin for Neovim

return {
  "stevearc/overseer.nvim",
  cmd = {
    "OverseerOpen",
    "OverseerClose",
    "OverseerToggle",
    "OverseerRun",
    "OverseerShell",
    "OverseerTaskAction",
  },
  -- stylua: ignore
  keys = {
    { "<leader>ow", "<cmd>OverseerToggle<cr>",      desc = "Task list" },
    { "<leader>oo", "<cmd>OverseerRun<cr>",         desc = "Run task" },
    { "<leader>ot", "<cmd>OverseerTaskAction<cr>",  desc = "Task action" },
  },
  opts = {},
  specs = {
    {
      "folke/which-key.nvim",
      opts = {
        ---@module "which-key"
        ---@type wk.Spec
        spec = {
          { "<leader>o", group = "overseer" },
        },
      },
    },
  },
}
