-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

require("lualine").setup {
  options = {
    icons_enabled = true,
  },

  extensions = {
    "fugitive",
    "fzf",
    "man",
    "nvim-tree",
    "quickfix",
  },

  sections = {
    lualine_c = {
      {
        "filename",
        show_filename_only = false,
        path = 3,
        shorting_target = 80,
      }
    }
  }
}
