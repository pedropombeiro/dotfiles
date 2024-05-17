-- mini-comment (https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-comment.md)
--   🧠 💪 // Smart and powerful comment plugin for neovim. Supports treesitter, dot repeat, left-right/up-down motions,
--   hooks, and more

return {
  'echasnovski/mini.comment',
  cond = function()
    return vim.fn.has('nvim-0.10') == 0
  end,
  event = { 'BufNewFile', 'BufReadPre' },
  opts = {},
}
