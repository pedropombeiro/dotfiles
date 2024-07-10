-- outline.nvim (https://github.com/hedyhli/outline.nvim)
--  Code outline sidebar powered by LSP. Significantly enhanced & refactored fork of symbols-outline.nvim.

return {
  'hedyhli/outline.nvim',
  cmd = { 'Outline', 'OutlineOpen' },
  keys = {
    { '<C-|>', ':Outline<CR>', mode = { 'n', 'v' }, desc = 'Toggle symbols window', silent = true },
  },
  opts = function()
    local config = require('config')

    return {
      symbol_folding = {
        markers = { config.ui.icons.folder.collapsed, config.ui.icons.folder.expanded },
      },
      outline_items = {
        show_symbol_lineno = true,
      },
      symbols = {
        icons = {
          File = { icon = config.ui.icons.kinds.File, hl = 'Identifier' },
          Module = { icon = config.ui.icons.kinds.Module, hl = 'Include' },
          Namespace = { icon = config.ui.icons.kinds.Namespace, hl = 'Include' },
          Package = { icon = config.ui.icons.kinds.Package, hl = 'Include' },
          Class = { icon = config.ui.icons.kinds.Class, hl = 'Type' },
          Method = { icon = config.ui.icons.kinds.Method, hl = 'Function' },
          Property = { icon = config.ui.icons.kinds.Property, hl = 'Identifier' },
          Field = { icon = config.ui.icons.kinds.Field, hl = 'Identifier' },
          Constructor = { icon = config.ui.icons.kinds.Constructor, hl = 'Special' },
          Enum = { icon = config.ui.icons.kinds.Enum, hl = 'Type' },
          Interface = { icon = config.ui.icons.kinds.Interface, hl = 'Type' },
          Function = { icon = config.ui.icons.kinds.Function, hl = 'Function' },
          Variable = { icon = config.ui.icons.kinds.Variable, hl = 'Constant' },
          Constant = { icon = config.ui.icons.kinds.Constant, hl = 'Constant' },
          String = { icon = config.ui.icons.kinds.String, hl = 'String' },
          Number = { icon = config.ui.icons.kinds.Number, hl = 'Number' },
          Boolean = { icon = config.ui.icons.kinds.Boolean, hl = 'Boolean' },
          Array = { icon = config.ui.icons.kinds.Array, hl = 'Constant' },
          Object = { icon = config.ui.icons.kinds.Object, hl = 'Type' },
          Key = { icon = config.ui.icons.kinds.Key, hl = 'Type' },
          Null = { icon = config.ui.icons.kinds.Null, hl = 'Type' },
          EnumMember = { icon = config.ui.icons.kinds.EnumMember, hl = 'Identifier' },
          Struct = { icon = config.ui.icons.kinds.Struct, hl = 'Structure' },
          Event = { icon = config.ui.icons.kinds.Event, hl = 'Type' },
          Operator = { icon = config.ui.icons.kinds.Operator, hl = 'Identifier' },
          TypeParameter = { icon = config.ui.icons.kinds.TypeParameter, hl = 'Identifier' },
          Component = { icon = config.ui.icons.kinds.Module, hl = 'Function' },
          Fragment = { icon = config.ui.icons.kinds.Snippet, hl = 'Constant' },
          TypeAlias = { icon = config.ui.icons.kinds.TypeAlias, hl = 'Type' },
          Parameter = { icon = config.ui.icons.kinds.TypeParameter, hl = 'Identifier' },
          StaticMethod = { icon = config.ui.icons.kinds.Function, hl = 'Function' },
          Macro = { icon = config.ui.icons.kinds.Macro, hl = 'Function' },
        },
      },
    }
  end,
}
