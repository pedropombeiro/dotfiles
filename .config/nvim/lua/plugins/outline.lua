-- outline.nvim (https://github.com/hedyhli/outline.nvim)
--  Fancy code outline sidebar to visualize and navigate code symbols in a tree hierarchy

return {
  "hedyhli/outline.nvim",
  cmd = { "Outline", "OutlineOpen" },
  ---@type LazyKeysSpec[]
  keys = {
    { "<C-|>", ":Outline<CR>", mode = { "n", "v" }, desc = "Toggle symbols window", silent = true },
  },
  opts = function()
    ---@type pmsp.neovim.Config
    local config = require("config")
    local function with_padding(icon) return icon .. " " end

    return {
      symbol_folding = {
        markers = { config.ui.icons.folder.collapsed, config.ui.icons.folder.expanded },
      },
      outline_items = {
        show_symbol_lineno = true,
      },
      symbols = {
        icons = {
          Array = { icon = with_padding(config.ui.icons.kinds.Array), hl = "Constant" },
          Boolean = { icon = with_padding(config.ui.icons.kinds.Boolean), hl = "Boolean" },
          Class = { icon = with_padding(config.ui.icons.kinds.Class), hl = "Type" },
          Component = { icon = with_padding(config.ui.icons.kinds.Module), hl = "Function" },
          Constant = { icon = with_padding(config.ui.icons.kinds.Constant), hl = "Constant" },
          Constructor = { icon = with_padding(config.ui.icons.kinds.Constructor), hl = "Special" },
          Enum = { icon = with_padding(config.ui.icons.kinds.Enum), hl = "Type" },
          EnumMember = { icon = with_padding(config.ui.icons.kinds.EnumMember), hl = "Identifier" },
          Event = { icon = with_padding(config.ui.icons.kinds.Event), hl = "Type" },
          Field = { icon = with_padding(config.ui.icons.kinds.Field), hl = "Identifier" },
          File = { icon = with_padding(config.ui.icons.kinds.File), hl = "Identifier" },
          Fragment = { icon = with_padding(config.ui.icons.kinds.Snippet), hl = "Constant" },
          Function = { icon = with_padding(config.ui.icons.kinds.Function), hl = "Function" },
          Interface = { icon = with_padding(config.ui.icons.kinds.Interface), hl = "Type" },
          Key = { icon = with_padding(config.ui.icons.kinds.Key), hl = "Type" },
          Macro = { icon = with_padding(config.ui.icons.kinds.Macro), hl = "Function" },
          Method = { icon = with_padding(config.ui.icons.kinds.Method), hl = "Function" },
          Module = { icon = with_padding(config.ui.icons.kinds.Module), hl = "Include" },
          Namespace = { icon = with_padding(config.ui.icons.kinds.Namespace), hl = "Include" },
          Null = { icon = with_padding(config.ui.icons.kinds.Null), hl = "Type" },
          Number = { icon = with_padding(config.ui.icons.kinds.Number), hl = "Number" },
          Object = { icon = with_padding(config.ui.icons.kinds.Object), hl = "Type" },
          Operator = { icon = with_padding(config.ui.icons.kinds.Operator), hl = "Identifier" },
          Package = { icon = with_padding(config.ui.icons.kinds.Package), hl = "Include" },
          Parameter = { icon = with_padding(config.ui.icons.kinds.TypeParameter), hl = "Identifier" },
          Property = { icon = with_padding(config.ui.icons.kinds.Property), hl = "Identifier" },
          StaticMethod = { icon = with_padding(config.ui.icons.kinds.Function), hl = "Function" },
          String = { icon = with_padding(config.ui.icons.kinds.String), hl = "String" },
          Struct = { icon = with_padding(config.ui.icons.kinds.Struct), hl = "Structure" },
          TypeAlias = { icon = with_padding(config.ui.icons.kinds.TypeAlias), hl = "Type" },
          TypeParameter = { icon = with_padding(config.ui.icons.kinds.TypeParameter), hl = "Identifier" },
          Variable = { icon = with_padding(config.ui.icons.kinds.Variable), hl = "Constant" },
        },
      },
    }
  end,
}
