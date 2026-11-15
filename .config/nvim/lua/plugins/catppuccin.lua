return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  cond = function() return require("config.theme").nvim == "catppuccin-mocha" end,
  opts = {
    flavour = "mocha",
    custom_highlights = function(colors)
      return {
        FloatermBorder = { link = "FloatBorder" },
        SnacksPickerInputBorder = { fg = colors.blue, bg = colors.mantle },
        FoldColumn = { bg = "NONE", fg = colors.overlay1 },
        SignColumn = { bg = "NONE" },
      }
    end,
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}
