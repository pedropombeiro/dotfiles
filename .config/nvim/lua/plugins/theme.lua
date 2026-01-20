-- gruvbox (https://github.com/ellisonleao/gruvbox.nvim)
--  Lua port of the most famous vim colorscheme

---@type pmsp.neovim.Config
local config = require("config")
local theme = config.theme

return {
  "ellisonleao/gruvbox.nvim",
  lazy = false, -- Must load immediately for colorscheme
  priority = 1000, -- make sure to load this before all the other start plugins
  cond = function()
    local nvim_theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    if nvim_theme == nil then nvim_theme = theme.name end

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
      FloatBorder = { fg = theme.colors.dark_blue, bg = theme.colors.dark0 },
      FloatermBorder = { link = "FloatBorder" },
      LspInfoBorder = { link = "FloatBorder" },

      SnacksPickerInputBorder = { bg = theme.colors.dark0, fg = theme.colors.orange },
      SnacksPickerList = { bg = theme.colors.dark0 },
      SnacksPickerPreview = { bg = theme.colors.dark0 },
      SnacksPickerBorder = { link = "GruvboxBlue" },

      FoldColumn = { bg = "NONE" },
      SignColumn = { bg = "NONE" },
      GitSignsCurrentLineBlame = { fg = "#504945" },

      DiagnosticVirtualTextWarn = { fg = "#fabd2f", bg = "#473c29" },
      DiagnosticVirtualTextError = { fg = "#fb4934", bg = "#442e2d" },
      DiagnosticVirtualTextInfo = { fg = theme.colors.dark_blue, bg = "#2e3b3b" },
      DiagnosticVirtualTextHint = { fg = "#b8bb26", bg = "#333e34" },
      LspDiagnosticsVirtualTextWarning = { fg = "#fabd2f" },
      LspDiagnosticsVirtualTextError = { fg = "#fb4934" },
      LspDiagnosticsVirtualTextInfo = { fg = theme.colors.dark_blue },
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

      -- Markdown headings (softer colors)
      ["@markup.heading.1.markdown"] = { fg = "#fe8019", bold = true },
      ["@markup.heading.2.markdown"] = { fg = "#fabd2f", bold = true },
      ["@markup.heading.3.markdown"] = { fg = "#b8bb26", bold = true },
      ["@markup.heading.4.markdown"] = { fg = "#8ec07c", bold = true },
      ["@markup.heading.5.markdown"] = { fg = "#83a598", bold = true },
      ["@markup.heading.6.markdown"] = { fg = "#d3869b", bold = true },

      -- render-markdown heading backgrounds
      RenderMarkdownH1Bg = { bg = "#3c2a1e" },
      RenderMarkdownH2Bg = { bg = "#3a3424" },
      RenderMarkdownH3Bg = { bg = "#333e24" },
      RenderMarkdownH4Bg = { bg = "#2a3a32" },
      RenderMarkdownH5Bg = { bg = "#2a3540" },
      RenderMarkdownH6Bg = { bg = "#382e3a" },
    },
  },
}
