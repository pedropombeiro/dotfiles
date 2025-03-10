---@param table snacks.util.hl
---@param opts? { prefix?:string, default?:boolean, managed?:boolean }
function Set_hl(table, opts)
  Snacks.util.set_hl(table, opts)
end

-- stylua: ignore
---@class pmsp.neovim.Config
local config = {
  theme = {
    name = "gruvbox",
    colors = {
      dark0       = "#101011",
      bg0_s       = "#32302f", -- Gruvbox Dark bg0_s
      gray        = "#928374",
      fg          = "#ebdbb2",
      fg3         = "#bdae93",
      fg4         = "#a89984",
      dark_blue   = "#83a598",
      blue        = "#458588",
      cyan        = "#8ec07c",
      green_bg    = "#98971a",
      orange_bg   = "#d65d0e",
      orange      = "#fe8019",
      dark_red    = "#fb4934",
      red         = "#cc241d",
      dark_yellow = "#fabd2f",
      green       = "#b8bb26",
      purple      = "#d3869b",
    }
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
        passed     = "",
        running    = "",
        failed     = "",
        cancelled  = "⊘",
        skipped    = "◌",
        unknown    = ""
      }
    },
  },
}

return config
