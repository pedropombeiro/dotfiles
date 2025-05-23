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
      desc = "Open code action menu",
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
