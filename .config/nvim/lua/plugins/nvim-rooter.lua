-- nvim-rooter.lua (https://github.com/notjedi/nvim-rooter.lua)
--  minimal implementation of vim-rooter in lua.

return {
  "notjedi/nvim-rooter.lua",
  event = { "BufNewFile", "BufReadPost" },
  opts = {
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
      "*.yaml",
      "*.yml",
    },
    exclude_filetypes = {
      ["lazy"] = true,
      ["snacks_picker_input"] = true,
      ["snacks_picker_list"] = true,
      ["vimdoc"] = true,
    },
  },
}
