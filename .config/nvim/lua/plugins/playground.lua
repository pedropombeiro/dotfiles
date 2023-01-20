-- Neovim Treesitter Playground (https://github.com/nvim-treesitter/playground)
--  Treesitter playground integrated into Neovim

return {
  "nvim-treesitter/playground", -- Treesitter playground integrated into Neovim
  cmd = "TSPlaygroundToggle",
  dependencies = "nvim-treesitter/nvim-treesitter",
  build = ":TSInstall query",
  config = function()
    require "nvim-treesitter.configs".setup {
      query_linter = {
        enable = true,
        use_virtual_text = true,
        lint_events = { "BufWrite", "CursorHold" },
      },
    }
  end
}
