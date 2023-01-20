-- nvim-tree.lua (https://github.com/nvim-tree/nvim-tree.lua/)
--  A file explorer tree for neovim written in lua

local version = vim.version()
if (version.major == 0 and version.minor < 8) then
  return nil
end

return {
  "nvim-tree/nvim-tree.lua",
  cond = function() return not vim.g.started_by_firenvim end,
  event = "VeryLazy",
  dependencies = "kyazdani42/nvim-web-devicons",
  keys = {
    { "<C-\\>", "<Cmd>NvimTreeFindFileToggle<CR>", mode = { "n", "v" }, desc = "Toggle file explorer" }
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
  }
}
