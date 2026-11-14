-- difftastic.nvim (https://github.com/clabby/difftastic.nvim)
--   Side-by-side structural diffs from difftastic, with a file tree.

---@module "lazy"
---@type LazySpec
return {
  "clabby/difftastic.nvim",
  dependencies = { "MunifTanjim/nui.nvim", "folke/snacks.nvim" },
  -- The prebuilt library needs a newer glibc than QTS ships
  cond = function() return vim.g.distro ~= "qts" and vim.fn.executable("difft") == 1 end,
  cmd = { "Difft", "DifftPick", "DifftPickRange", "DifftClose", "DifftUpdate" },
  ---@type LazyKeysSpec[]
  keys = {
    { "<leader>gD", "<cmd>Difft<cr>", desc = "Difftastic: unstaged changes" },
    { "<leader>gP", "<cmd>DifftPick<cr>", desc = "Difftastic: pick a commit" },
  },
  config = function()
    require("difftastic-nvim").setup({
      -- Fetch the prebuilt library instead of building it with cargo. The download
      -- runs in the background, so the first :Difft after an update may ask to wait.
      download = true,
      vcs = "git",
      snacks_picker = { enabled = true },
    })
  end,
}
