-- nvim-rooter.lua (https://github.com/notjedi/nvim-rooter.lua)
--  minimal implementation of vim-rooter in lua.

require("nvim-rooter").setup {
  manual = false,
  rooter_patterns = {
    ".git",
    ".hg",
    ".svn",
    "Makefile",
  },
  trigger_patterns = {
    "*.go",
    "*.ino",
    "*.rb",
    "Makefile",
    "*.mk",
    "*.sh",
  },
}
