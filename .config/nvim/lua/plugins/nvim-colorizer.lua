-- catgoose/nvim-colorizer.lua (https://github.com/catgoose/nvim-colorizer.lua)
--  Maintained fork of the fastest Neovim colorizer

return {
  "catgoose/nvim-colorizer.lua",
  event = "BufReadPre",
  opts = {
    filetypes = {
      "*",
      "!lazy",
      cmp_docs = { always_update = true },
      markdown = { always_update = true },
    },
    -- all the sub-options of filetypes apply to buftypes
    buftypes = {
      "*",
      -- exclude prompt and popup buftypes from highlight
      "!FZF",
      "!Fm",
      "!Outline",
      "!Trouble",
      "!lazy",
      "!neotest-summary",
      "!popup",
      "!prompt",
      "!snacks_dashboard",
      "!snacks_picker_list",
    },
  },
}
