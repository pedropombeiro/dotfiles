-- unimpaired.vim (https://github.com/tpope/vim-unimpaired)
--   Pairs of handy bracket mappings

return {
  "tpope/vim-unimpaired",
  event = "BufReadPost",
  init = function()
    local wk = require("which-key")
    local m = require("mapx")

    m.nname("=", "Unimpaired")
    m.nname("[o", "Unimpaired - Enable")
    m.nname("]o", "Unimpaired - Disable")
    local unimpaired_option_mappings = {
      b = { "background" },
      c = { "cursorline" },
      d = { "diff" },
      h = { "hlsearch" },
      i = { "ignorecase" },
      l = { "list" },
      n = { "number" },
      r = { "relativenumber" },
      s = { "spell" },
      t = { "colorcolumn" },
      u = { "cursorcolumn" },
      v = { "virtualedit" },
      w = { "wrap" },
      x = { "cursorline + cursorcolumn" },
    }
    wk.register(unimpaired_option_mappings, { prefix = "[o" })
    wk.register(unimpaired_option_mappings, { prefix = "]o" })
    wk.register({
      ["[f"] = { "Go to prev file in folder" },
      ["]f"] = { "Go to next file in folder" },
      ["[n"] = { "Go to prev conflict/diff/hunk" },
      ["]n"] = { "Go to next conflict/diff/hunk" },
      ["[e"] = { "Exchange line with lines above" },
      ["]e"] = { "Exchange line with lines below" },
      ["[<Space>"] = { "Add empty lines above" },
      ["]<Space>"] = { "Add empty lines below" },
    })
    wk.register({
      ["[u"] = { "URL encode" },
      ["]u"] = { "URL decode" },
      ["[x"] = { "XML encode" },
      ["]x"] = { "XML decode" },
      ["[C"] = { "C String encode" },
      ["]C"] = { "C String decode" },
      ["[y"] = { "C String encode" },
      ["]y"] = { "C String decode" },
    }, { mode = { "n", "v" } })

    m.nname("=", "Unimpaired - Paste (reindending)")
    m.nname("<", "Unimpaired - Paste before linewise")
    m.nname(">", "Unimpaired - Paste after linewise")
  end
}
