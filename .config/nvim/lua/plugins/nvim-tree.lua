-- nvim-tree.lua (https://github.com/nvim-tree/nvim-tree.lua/)
--  A file explorer tree for neovim written in lua

local version = vim.version()
if (version.major == 0 and version.minor < 8) then
  return nil
end

local config = require("config")

return {
  "nvim-tree/nvim-tree.lua",
  cond = function() return not vim.g.started_by_firenvim end,
  cmd = { "NvimTreeFocus", "NvimTreeToggle", "NvimTreeFindFileToggle" },
  dependencies = "kyazdani42/nvim-web-devicons",
  keys = {
    { "<C-\\>", "<Cmd>NvimTreeFindFileToggle<CR>", mode = { "n", "v" }, desc = "Toggle file explorer" },
    {
      "gx", -- Restore URL handling from disabled netrw plugin
      function()
        if vim.fn.has("mac") == 1 then
          vim.cmd [[call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>]]
        elseif vim.fn.has("unix") == 1 then
          vim.cmd [[call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>]]
        else
          print("Error: gx is not supported on this OS!")
        end
      end,
      "Open URL"
    },
  },
  opts = {
    disable_netrw = false,
    hijack_netrw = true,
    reload_on_bufenter = true,
    sort_by = "case_sensitive",
    view = {
      adaptive_size = true,
      side = "right",
    },
    renderer = {
      group_empty = true,
      highlight_git = true,
      highlight_opened_files = "icon",
      icons = {
        git_placement = "signcolumn",
        show = {
          file         = true,
          folder       = false,
          folder_arrow = true,
          git          = true,
        },
        glyphs = {
          folder = {
            ---@diagnostic disable: undefined-field
            arrow_closed = config.icons.folder.collapsed,
            arrow_open   = config.icons.folder.expanded,
            ---@diagnostic enable: undefined-field
          }
        },
      },
    },
    filters = {
      dotfiles = false,
      custom = { "^.DS_Store$", "^.git$", ".zwc$" },
    },
    actions = {
      expand_all = {
        exclude = { ".git" },
      },
      open_file = {
        quit_on_open = true,
      },
    },
    update_focused_file = {
      enable = true,
      update_cwd = false,
    },
    diagnostics = {
      enable = true,
      show_on_dirs = true,
      icons = {
        ---@diagnostic disable: undefined-field
        hint    = config.icons.diagnostics.hint,
        info    = config.icons.diagnostics.info,
        warning = config.icons.diagnostics.warning,
        error   = config.icons.diagnostics.error,
        ---@diagnostic enable: undefined-field
      },
    },
  }
}
