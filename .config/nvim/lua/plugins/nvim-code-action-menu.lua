-- NeoVim Code Action Menu (https://github.com/aznhe21/actions-preview.nvim)
--  Fully customizable previewer for LSP code actions.

return {
  "aznhe21/actions-preview.nvim",
  ---@module "lazy"
  ---@type LazyKeysSpec[]
  keys = {
    {
      "gra",
      function() require("actions-preview").code_actions() end,
      mode = { "n", "v" },
      desc = "Open code action menu",
    },
    {
      "<leader>ca",
      function() require("actions-preview").code_actions() end,
      mode = { "n", "v" },
      desc = "Code actions",
    },
  },
  config = function()
    return {
      highlight_command = {
        require("actions-preview.highlight").delta(),
      },
    }
  end,
}
