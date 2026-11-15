return {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000,
  cond = function() return require("config.theme").nvim == "tokyonight-night" end,
  opts = {
    style = "night",
    dim_inactive = true,
    on_highlights = function(hl, colors)
      hl.FloatermBorder = { link = "FloatBorder" }
      hl.SnacksPickerInputBorder = { fg = colors.orange, bg = colors.bg_float }
      hl.FoldColumn = { bg = "NONE", fg = colors.comment }
      hl.SignColumn = { bg = "NONE" }
    end,
  },
  config = function(_, opts)
    require("tokyonight").setup(opts)
    vim.cmd.colorscheme("tokyonight-night")
  end,
}
