-- pipeline.nvim (https://github.com/topaxi/pipeline.nvim)
--  See status of ci/cd pipeline runs directly in neovim.

return {
  "topaxi/pipeline.nvim",
  cond = function() return not vim.g.started_by_firenvim and vim.fn.executable("gh") == 1 end,
  ---@module "lazy"
  ---@type LazyKeysSpec[]
  keys = {
    { "<leader>ci", "<cmd>Pipeline<cr>", desc = "Open pipeline.nvim" },
  },
  opts = function()
    ---@type pmsp.neovim.Config
    local config = require("config")
    local icons = config.ui.icons.tests

    return {
      icons = {
        workflow_dispatch = "",
        conclusion = {
          success = icons.passed,
          failure = icons.failed,
          startup_failure = icons.failed,
          cancelled = icons.cancelled,
          skipped = icons.skipped,
        },
        status = {
          unknown = icons.unknown,
          pending = icons.running,
          queued = icons.running,
          requested = icons.running,
          waiting = icons.running,
          in_progress = "●",
        },
      },
      split = {
        win_options = {
          relativenumber = false,
          cursorline = false,
        },
      },
    }
  end,
}
