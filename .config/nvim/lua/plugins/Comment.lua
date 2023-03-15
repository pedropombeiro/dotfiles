-- Comment.nvim (https://github.com/numToStr/Comment.nvim)
--   🧠 💪 // Smart and powerful comment plugin for neovim. Supports treesitter, dot repeat, left-right/up-down motions,
--   hooks, and more

return {
  "numToStr/Comment.nvim",
  keys = {
    { "gc", mode = { "n", "v" } },
    { "gb", mode = { "n", "v" } },
  },
  opts = function()
    local commentstring_avail, commentstring = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
    return commentstring_avail and commentstring and { pre_hook = commentstring.create_pre_hook() } or {}
  end,
}
