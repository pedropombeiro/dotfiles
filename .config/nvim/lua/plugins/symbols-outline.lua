-- symbols-outline (https://github.com/simrat39/symbols-outline.nvim)
--  A tree like view for symbols in Neovim using the Language Server Protocol. Supports all your favourite languages.

return {
  "simrat39/symbols-outline.nvim",
  cmd = "SymbolsOutline",
  keys = {
    { "<C-'>", ":SymbolsOutline<CR>", mode = { "n", "v" }, desc = "Toggle symbols window" }
  },
  opts = {
    auto_close = false,
    keymaps = { -- These keymaps can be a string or a table for multiple keys
      close = { "<Esc>", "q" },
      goto_location = "<Cr>",
      focus_location = "<Tab>",
      hover_symbol = "<C-space>",
      toggle_preview = "K",
      rename_symbol = "r",
      code_actions = "a",
      fold = "h",
      unfold = "l",
      fold_all = "W",
      unfold_all = "E",
      fold_reset = "R",
    },
  }
}
