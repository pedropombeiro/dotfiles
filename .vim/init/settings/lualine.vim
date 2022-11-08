" -- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
if has("nvim")
  lua << EOF
  require('lualine').setup {
    options = {
      icons_enabled = true,
    },

    extensions = {
      'fugitive',
      'fzf',
      'nvim-tree',
      'quickfix',
    },

    sections = {
      lualine_c = {
        {
          'filename',
          show_filename_only = false,
          path = 3,
          shorting_target = 80,
        }
      }
    }
  }
EOF
endif