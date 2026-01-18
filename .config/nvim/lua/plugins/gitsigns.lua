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
  wk.add( ---@type wk.Spec
    {
      buffer = bufnr,
      {
        icon = "",
        { "<leader>gh", group = "Gitsigns" },
        { "<leader>ghs", ":Gitsigns stage_hunk<CR>", desc = "Stage Git hunk", mode = { "n", "v" }, icon = "" },
        { "<leader>ghu", gs.undo_stage_buffer, desc = "Undo stage Git hunk", icon = "" },
        { "<leader>ghr", ":Gitsigns reset_hunk<CR>", desc = "Reset Git hunk", mode = { "n", "v" } },
        { "<leader>ghq", ":Gitsigns setqflist<CR>", desc = "Open changes in Quickfix list" },
        { "<leader>ghp", gs.preview_hunk_inline, desc = "Preview Git hunk", icon = "" },
        { "<leader>ghS", gs.stage_buffer, desc = "Stage buffer" },
        { "<leader>ghR", gs.reset_buffer, desc = "Reset buffer" },
        { "<leader>ghb", function() gs.blame_line({ full = true }) end, desc = "Git blame line" },
        { "<leader>ghd", gs.diffthis, desc = "Git diff this" },
        { "<leader>ghD", function() gs.diffthis("~") end, desc = "Git diff this ~", icon = "" },
        {
          expr = true,
          mode = { "n" },
          {
            -- Navigation
            {
              "[H",
              function() gs.nav_hunk("first") end,
              desc = "First Git hunk",
              icon = "󰮳",
            },
            {
              "]H",
              function() gs.nav_hunk("last") end,
              desc = "Last Git hunk",
              icon = "󰮳",
            },
            {
              "[h",
              function()
                if vim.wo.diff then
                  vim.cmd.normal({ "]c", bang = true })
                else
                  gs.nav_hunk("next")
                end
              end,
              desc = "Previous Git hunk",
              icon = "󰮳",
            },
            {
              "]h",
              function()
                if vim.wo.diff then
                  vim.cmd.normal({ "[c", bang = true })
                else
                  gs.nav_hunk("prev")
                end
              end,
              desc = "Next Git hunk",
              icon = "󰮱",
            },
            -- Options
            { "[g", group = "Enable Git option", icon = "" },
            { "[gb", function() gs.toggle_current_line_blame(true) end, desc = "Enable current line blame" },
            { "[gd", function() gs.toggle_deleted(true) end, desc = "Enable Git-deleted" },
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
    }
  )
end

return {
  {
    "purarue/gitsigns-yadm.nvim",
    lazy = true,
    cond = function() return vim.fn.executable("yadm") == 1 end,
    ---@module "gitsigns-yadm"
    ---@type GitsignsYadm.Config
    opts = {
      disable_inside_gitdir = true,
      on_yadm_attach = function()
        -- set a buffer-local variable so that other code can run custom
        -- code if we're editing a yadm file
        vim.b.yadm_tracked = true
      end,
    },
  },
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    ---@module "gitsigns"
    ---@type Gitsigns.Config
    ---@diagnostic disable: missing-fields
    opts = {
      _on_attach_pre = function(bufnr, callback)
        local plugins = require("lazy.core.config").plugins
        if plugins["gitsigns-yadm.nvim"] ~= nil then
          require("gitsigns-yadm").yadm_signs(callback, { bufnr = bufnr })
        else
          callback({ bufnr = bufnr })
        end
      end,
      signs = {
        add = { text = "▌", show_count = true },
        change = { text = "▌", show_count = true },
        delete = { text = "▐", show_count = true },
        topdelete = { text = "▛", show_count = true },
        changedelete = { text = "▚", show_count = true },
        untracked = { text = "▎" },
      },
      signs_staged = {
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
    ---@diagnostic enable: missing-fields
    init = function()
      -- Ensure that gitsigns is loaded when opening a file directly, so that gitsigns-yadm has a chance to process it
      -- Use vim.schedule to defer loading until after vim-fetch processes file:line arguments
      if vim.fn.argc() > 0 then
        vim.schedule(function()
          require("gitsigns")
        end)
      end
    end,
    config = function(_, opts)
      require("gitsigns").setup(opts)

      -- Compare with the default branch
      local branch = string.match(vim.fn.system("git branch -rl '*/HEAD'"), ".*/(.*)\n")
      if branch then require("gitsigns").change_base(branch, true) end
    end,
  },
}
