-- yazi.nvim (https://github.com/mikavilpas/yazi.nvim)
-- A Neovim Plugin for the yazi terminal file manager

---@module "lazy"
---@type LazySpec
return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  dependencies = { "folke/snacks.nvim", lazy = true },
  keys = {
    {
      "<leader>F",
      mode = { "n", "v" },
      "<cmd>Yazi<cr>",
      desc = "Open yazi at the current file",
    },
    {
      "gx", -- Restore URL handling from disabled netrw plugin
      function() vim.ui.open(vim.fn.expand("<cfile>")) end,
      desc = "Open URL",
    },
  },
  ---@module "yazi"
  ---@type YaziConfig | {}
  opts = {
    -- if you want to open yazi instead of netrw, see below for more info
    open_for_directories = true,
    keymaps = {
      show_help = "<f1>",
    },
    integrations = {
      grep_in_directory = function(directory)
        Snacks.picker.grep({ cwd = directory })
      end,
    },
  },
  -- 👇 if you use `open_for_directories=true`, this is recommended
  init = function()
    -- More details: https://github.com/mikavilpas/yazi.nvim/issues/802
    -- vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
  end,
}
