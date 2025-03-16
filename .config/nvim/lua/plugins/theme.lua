-- gruvbox (https://github.com/ellisonleao/gruvbox.nvim)
--  Lua port of the most famous vim colorscheme

---@type pmsp.neovim.Config
local config = require("config")
local theme = config.theme

return {
  "ellisonleao/gruvbox.nvim",
  lazy = false,
  priority = 1000, -- make sure to load this before all the other start plugins
  cond = function()
    local nvim_theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if nvim_theme == nil then
      nvim_theme = theme.name
    end

    return nvim_theme == "gruvbox"
  end,
  config = function(_, opts)
    require("gruvbox").setup(opts)

    vim.cmd("colorscheme " .. theme.name)
  end,
  opts = {
    contrast = "hard",
    dim_inactive = true,
    transparent_mode = false,
    overrides = {
      Normal = { bg = theme.colors.dark0 },

      -- Change border for float windows (normally grey)
      NormalFloat = { bg = theme.colors.dark0 },
      FloatBorder = { fg = "#83a598", bg = theme.colors.dark0 },
      FloatermBorder = { link = "FloatBorder" },
      LspInfoBorder = { link = "FloatBorder" },

      FoldColumn = { bg = "NONE" },
      SignColumn = { bg = "NONE" },
      GitSignsCurrentLineBlame = { fg = "#504945" },

      DiagnosticVirtualTextWarn = { fg = "#fabd2f", bg = "#473c29" },
      DiagnosticVirtualTextError = { fg = "#fb4934", bg = "#442e2d" },
      DiagnosticVirtualTextInfo = { fg = "#83a598", bg = "#2e3b3b" },
      DiagnosticVirtualTextHint = { fg = "#b8bb26", bg = "#333e34" },
      LspDiagnosticsVirtualTextWarning = { fg = "#fabd2f" },
      LspDiagnosticsVirtualTextError = { fg = "#fb4934" },
      LspDiagnosticsVirtualTextInfo = { fg = "#83a598" },
      LspDiagnosticsVirtualTextHint = { fg = "#b8bb26" },

      -- Remove background from signs (since we made the sign column not have a background)
      GruvboxYellowSign = { link = "GruvboxYellow" },
      GruvboxRedSign = { link = "GruvboxRed" },
      GruvboxAquaSign = { link = "GruvboxAqua" },

      -- Change border for LSP elements, to make them more recognizable (same colors as the bat gruvbox theme)
      ["@field"] = { link = "GruvboxRed" },
      ["@constant"] = { link = "GruvboxBlue" },
      ["@string"] = { link = "GruvboxGreen" },

      ["@constant.bash"] = { link = "GruvboxBlueBold" },
      ["@string.bash"] = { link = "GruvboxFg1" },

      -- Go
      ["@constant.go"] = { link = "GruvboxYellow" },
      ["@field.go"] = { link = "GruvboxBlue" },
      ["@include.go"] = { link = "GruvboxRed" },
      ["@namespace.go"] = { link = "GruvboxBlue" },
      ["@type.go"] = { link = "GruvboxRed" },
      ["@variable.go"] = { link = "GruvboxBlue" },

      -- Lua
      ["@function.call.lua"] = { link = "GruvboxAqua" },
      ["@keyword.function.lua"] = { link = "GruvboxBlueBold" },
      ["@lsp.type.function.lua"] = { link = "GruvboxAqua" },
      ["@lsp.type.property.lua"] = { link = "GruvboxAqua" },
      ["@lsp.type.variable.lua"] = { link = "GruvboxBlue" },

      -- Ruby
      ["@constant.builtin.ruby"] = { link = "GruvboxPurple" },
      ["@function.call.ruby"] = { link = "GruvboxAqua" },
      ["@punctuation.bracket.ruby"] = { link = "GruvboxFg1" },
      ["@string.ruby"] = { link = "GruvboxGreen" },
      ["@symbol.ruby"] = { link = "GruvboxPurple" },
      ["@variable.builtin.ruby"] = { link = "GruvboxPurple" },

      -- YAML
      ["@field.yaml"] = { link = "GruvboxBlueBold" },
      ["@string.yaml"] = { link = "GruvboxGreen" },
    },
  },
}
