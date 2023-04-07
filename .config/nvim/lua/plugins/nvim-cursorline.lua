-- nvim-cursorline (https://github.com/yamatsum/nvim-cursorline)
--  A plugin for neovim that highlights cursor words and lines

return {
  'yamatsum/nvim-cursorline',
  opts = {
    cursorline = {
      enable = true,
      timeout = 1000,
      number = false,
    },
    cursorword = {
      enable = true,
      min_length = 3,
      hl = { underline = true },
    }
  }
}
