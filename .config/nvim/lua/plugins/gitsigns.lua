-- gitsigns.nvim (https://github.com/lewis6991/gitsigns.nvim)
--  Git integration for buffers

local on_attach = function(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if vim.fn.expand("%:t") == "lsp.log" or vim.bo.filetype == "help" then return false end

  local size = vim.fn.getfsize(name)
  if size > 1024 * 1024 * 5 then return false end

  local gs = package.loaded.gitsigns
  local wk = require("which-key")

  -- Actions
  wk.add({
    buffer = bufnr,
    {
      icon = "",
      { "<leader>h", group = "Gitsigns" },
      { "<leader>hs", ":Gitsigns stage_hunk<CR>", desc = "Stage Git hunk", mode = { "n", "v" }, icon = "" },
      { "<leader>hu", gs.undo_stage_buffer, desc = "Undo stage Git hunk", icon = "" },
      { "<leader>hr", ":Gitsigns reset_hunk<CR>", desc = "Reset Git hunk", mode = { "n", "v" } },
      { "<leader>hq", ":Gitsigns setqflist<CR>", desc = "Open changes in Quickfix list" },
      { "<leader>hp", gs.preview_hunk_inline, desc = "Preview Git hunk", icon = "" },
      { "<leader>hS", gs.stage_buffer, desc = "Stage buffer" },
      { "<leader>hR", gs.reset_buffer, desc = "Reset buffer" },
      { "<leader>hb", function() gs.blame_line({ full = true }) end, desc = "Git blame line" },
      { "<leader>hd", gs.diffthis, desc = "Git diff this" },
      { "<leader>hD", function() gs.diffthis("~") end, desc = "Git diff this ~", icon = "" },
      {
        expr = true,
        {
          {
            -- Navigation
            "[c",
            function()
              if vim.wo.diff then return "[c" end
              vim.schedule(gs.prev_hunk)
              return "<Ignore>"
            end,
            desc = "Previous Git hunk",
            icon = "󰮳",
          },
          {
            -- Navigation
            "]c",
            function()
              if vim.wo.diff then return "]c" end
              vim.schedule(gs.next_hunk)
              return "<Ignore>"
            end,
            desc = "Next Git hunk",
            icon = "󰮱",
          },
          {
            -- Options
            { "[g", group = "Enable Git option", icon = "" },
            { "[gb", function() gs.toggle_current_line_blame(true) end, desc = "Enable current line blame" },


            { "[gd", function() gs.toggle_deleted(true) end, desc = "Enable Git-deleted" },
          },
          -- Options
          { "]g", group = "Disable Git option", icon = "" },
          { "]gb", function() gs.toggle_current_line_blame(false) end, desc = "Disable current line blame" },
          { "]gd", function() gs.toggle_deleted(false) end, desc = "Disable Git-deleted" },
        },
      },
      {
        -- Text object
        mode = { "o", "x" },
        { "i", group = "Text object" },
        { "ih", function() gs.select_hunk() end, desc = "Select Git hunk" },
      },
    },
  })
end

return {
  "lewis6991/gitsigns.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  cond = function()
    local is_git_repo = vim.fn.systemlist({ "git", "rev-parse", "--is-inside-work-tree" })[1] == "true"
    return is_git_repo
  end,
  opts = {
    signs = {
      add = { text = "▌", show_count = true },
      change = { text = "▌", show_count = true },
      delete = { text = "▐", show_count = true },
      topdelete = { text = "▛", show_count = true },
      changedelete = { text = "▚", show_count = true },
      untracked = { text = "▎" },
    },
    update_debounce = 500,
    sign_priority = 10,
    numhl = false,
    signcolumn = true,
    current_line_blame = true,
    count_chars = {
      [1] = "",
      [2] = "₂",
      [3] = "₃",
      [4] = "₄",
      [5] = "₅",
      [6] = "₆",
      [7] = "₇",
      [8] = "₈",
      [9] = "₉",
      ["+"] = "₊",
    },
    diff_opts = {
      internal = true,
      algorithm = "patience",
      indent_heuristic = true,
      linematch = 60,
    },
    on_attach = on_attach,
    preview_config = {
      -- Options passed to nvim_open_win
      border = require("config").ui.border,
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
  },
  config = function(_, opts)
    require("gitsigns").setup(opts)
    require("scrollbar.handlers.gitsigns").setup()

    -- Compare with the default branch
    local branch = string.match(vim.fn.system("git branch -rl '*/HEAD'"), ".*/(.*)\n")
    if branch then require("gitsigns").change_base(branch, true) end
  end,
}
