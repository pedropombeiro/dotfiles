-- Neovim Treesitter Playground (https://github.com/nvim-treesitter/playground)
--  Treesitter playground integrated into Neovim

require "nvim-treesitter.configs".setup {
  query_linter = {
    enable = true,
    use_virtual_text = true,
    lint_events = { "BufWrite", "CursorHold" },
  },
}
