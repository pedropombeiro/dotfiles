---@param table snacks.util.hl
---@param opts? { prefix?:string, default?:boolean, managed?:boolean }
function Set_hl(table, opts)
  Snacks.util.set_hl(table, opts)
end

-- stylua: ignore
---@class pmsp.neovim.Config
local config = {
  theme = {
    name = require("config.theme").nvim,
    lualine = require("config.theme").lualine,
    colors = require("config.themes." .. require("config.theme").nvim),
  },
  ui = {
    border = "rounded",
    icons = {
      folder = {
        empty      = "",
        empty_open = "",
        collapsed  = "",
        expanded   = "",
      },
      expander = {
        collapsed = "",
        expanded  = "",
      },
      diagnostics = {
        debug   = "",
        hint    = "",
        trace   = "󰏫",
        info    = "",
        warning = "",
        error   = "",
      },
      kinds = {
        Array         = "",
        Boolean       = "󰨙",
        Class         = "",
        Color         = "",
        Constant      = "󰏿",
        Constructor   = "",
        Control       = "",
        Copilot       = "",
        Enum          = "",
        EnumMember    = "",
        Event         = "",
        Field         = "",
        File          = "",
        Folder        = "󰉋",
        Function      = "󰊕",
        Interface     = "",
        Key           = "󰌋",
        Keyword       = "󰻾",
        Macro         = "",
        Method        = "󰊕",
        Module        = "",
        Namespace     = "󰦮",
        Null          = "",
        Number        = "󰎠",
        Object        = "",
        Operator      = "",
        Package       = "󰏖",
        Property      = "",
        Reference     = "",
        Snippet       = "",
        String        = "",
        Struct        = "󱡠",
        Text          = "󰉿",
        TypeAlias     = "",
        TypeParameter = "",
        Unit          = "",
        Value         = "󰦨",
        Variable      = "󰀫",
      },
      symbols = {
        added    = "",
        modified = "",
        removed  = "",
        renamed  = "󰁕",
        staged   = " ",
        unstaged = "󰄱",
        readonly = "",
      },
      tests = {
        passed           = "",
        running          = "",
        running_animated = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
        failed           = "",
        canceled         = "⊘",
        skipped          = "◌",
        unknown          = ""
      }
    },
  },
}

return config
