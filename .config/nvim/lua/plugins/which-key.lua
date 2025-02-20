-- which-key (https://github.com/folke/which-key.nvim)
--   💥 Create key bindings that stick. WhichKey is a lua plugin for Neovim 0.5 that displays
--   a popup with possible keybindings of the command you started typing.

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  ---@type LazyKeysSpec[]
  keys = {
    {
      "<leader>?",
      function() require("which-key").show({ global = false }) end,
      desc = "Buffer-local Keymaps (which-key)",
    },
  },
  ---@type wk.Opts
  opts = {
    preset = "modern",
    win = {
      border = require("config").ui.border,
    },
    spec = {
      -- Workaround: Fix <s-space> being rendered as 32;2u in LazyGit
      -- https://neovim.discourse.group/t/shift-space-escape-sequence-in-term-introduced-between-in-neovim-0-6-and-0-7/2816
      { "<S-Space>", "<Space>", mode = "t", remap = false, hidden = true },
      -- Map Esc to normal mode in terminal mode
      { "<Esc><Esc>", "<C-\\><C-n>", mode = "t", remap = false, hidden = true },
      -- make . work with visually selected lines
      { ".", ":normal.<CR>", mode = "v", remap = false, hidden = true },

      { "z", group = "Folds", icon = "" },
      { "<C-L>", desc = "Remove highlight", icon = "" },

      { "&", ":&&<CR>", mode = { "n", "x" }, hidden = true },

      { "<leader>t", group = "Terminal" },

      -- Switch between recently edited buffers (Mastering Vim Quickly)
      { "<C-b>", "<C-^>", desc = "Switch to recent buffer", silent = false },
      { "<C-b>", "<Esc><C-^>", desc = "Switch to recent buffer", mode = "i" },

      { "<C-s>", ":w<CR>", desc = "Save file" },
      { "<C-s>", "<Esc>:w<CR>", desc = "Save file", mode = "i" },
      { "<C-q>", ":qa<CR>", desc = "Quit all" },
      { "<C-q>", "<Esc>:qa<CR>", desc = "Quit all", mode = "i" },

      -- Center next/previous matches on the screen (Mastering Vim Quickly)
      { "n", "nzz", desc = "Next match (centered)" },
      { "N", "Nzz", desc = "Previous match (centered)" },

      ---- Move lines with single key combo (Mastering Vim Quickly)
      -- Normal mode
      { "<C-j>", "<Esc>:m .+1<CR>==", desc = "Move line up", mode = "n", remap = false, silent = true },
      { "<C-k>", "<Esc>:m .-2<CR>==", desc = "Move line down", mode = "n", remap = false, silent = true },

      -- Insert mode
      { "<C-j>", "<Esc>:m .+1<CR>==gi", desc = "Move line up", mode = "i", remap = false, silent = true },
      { "<C-k>", "<Esc>:m .-2<CR>==gi", desc = "Move line down", mode = "i", remap = false, silent = true },

      -- Visual mode
      { "<C-j>", ":m '>+1<CR>gv=gv", desc = "Move line up", mode = "v", remap = false, silent = true },
      { "<C-k>", ":m '<-2<CR>gv=gv", desc = "Move line down", mode = "v", remap = false, silent = true },

      { "<leader>~", ":<C-U>setlocal lcs=tab:>-,trail:-,eol:$ list! list? <CR>", desc = "Toggle special characters" },

      -- Map gp to select recently pasted text
      -- (https://vim.fandom.com/wiki/Selecting_your_pasted_text)
      { "gp", "'`[' . strpart(getregtype(), 0, 1) . '`]'", expr = true, desc = "Select last pasted text" },

      -- ========================================
      -- General vim sanity improvements
      -- ========================================
      --
      --
      { "Y", "yy", desc = "Yank lines" },

      {
        { "<leader>y", group = "Yank", icon = "" },
        { "<leader>yy", ":let @*=expand('%')<CR>", silent = false, desc = "Yank file path" },

        -- alias yw to yank the entire word 'yank inner word'
        -- even if the cursor is halfway inside the word
        -- FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
        { "<leader>yw", "yiww", desc = "Yank whole inner word", remap = true, silent = false, icon = "" },
      },

      -- <leader>ow = 'overwrite word', replace a word with what's in the yank buffer
      -- FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
      { "<leader>o", group = "Overwrite", icon = "" },
      { "<leader>ow", '"_diwhp', desc = "Overwrite whole word", remap = true, silent = false },

      { "gv", "`[v`]", desc = "Select last pasted text" },

      -- Window movement
      {
        mode = { "n", "t" },
        { "<C-S-Down>", "<cmd>resize -2<CR>", desc = "Resize window down" },
        { "<C-S-Left>", "<cmd>vertical resize +2<CR>", desc = "Resize window left" },
        { "<C-S-Right>", "<cmd>vertical resize -2<CR>", desc = "Resize window right" },
        { "<C-S-Up>", "<cmd>resize +2<CR>", desc = "Resize window up" },
      },
      {
        silent = false,
        { "<C-S-h>", "<cmd>wincmd h<CR>", desc = "Move to window to left" },
        { "<C-S-j>", "<cmd>wincmd j<CR>", desc = "Move to window below" },
        { "<C-S-k>", "<cmd>wincmd k<CR>", desc = "Move to window above" },
        { "<C-S-l>", "<cmd>wincmd l<CR>", desc = "Move to window to right" },
      },

      -- Surround
      {
        remap = true,
        icon = "",
        {
          mode = "n",
          { "<leader>#", "gsaiw#", desc = "Surround word with #{}" },
          { '<leader>"', 'gsaiw"', desc = "Surround word with quotes" },
          { "<leader>'", "gsaiw'", desc = "Surround word with single quotes" },
          { "<leader>`", "gsaiw`", desc = "Surround word with ticks" },
        },
        {
          mode = "v",
          { "<leader>#", 'c#{<C-R>"}<Esc>', desc = "Surround word with #{}" },
          { '<leader>"', 'c"<C-R>""<Esc>', desc = "Surround word with quotes" },
          { "<leader>'", "c'<C-R>\"'<Esc>", desc = "Surround word with single quotes" },
        },
      },

      { "<leader>g", group = "Git / Change action" },

      -- folke/persistence.nvim
      { "<leader>q", group = "Session management" },

      -- Lazy.nvim
      { "<leader>p", group = "Package Manager", icon = "" },
      { "<leader>ps", function() require("lazy").home() end, desc = "Status", icon = "󱖫" },
      { "<leader>pu", function() require("lazy").sync() end, desc = "Sync", icon = "" },

      -- wsdjeg/vim-fetch
      { "gF", mode = { "n", "x" }, desc = "Go to file:line under cursor" },
    },
  },
  ---@param opts wk.Opts
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- <leader>) or <leader>( Surround a word with (parens)
    -- The difference is in whether a space is put in
    local symbols = { ["("] = ")", ["["] = "]", ["{"] = "}" }
    for open_sym, close_sym in pairs(symbols) do
      local open_desc = "Surround word with " .. open_sym .. " " .. close_sym
      local close_desc = "Surround word with " .. open_sym .. close_sym

      wk.add({
        remap = true,
        icon = "",
        {
          mode = "n",
          { "<leader>" .. open_sym, "gsaiw" .. open_sym, desc = open_desc },
          { "<leader>" .. close_sym, "gsaiw" .. close_sym, desc = close_desc },
        },
        {
          mode = "v",
          { "<leader>" .. open_sym, "c" .. open_sym .. ' <C-R>"' .. close_sym .. "<Esc>", desc = open_desc },
          { "<leader>" .. close_sym, "c" .. open_sym .. '<C-R>"' .. close_sym .. "<Esc>", desc = close_desc },
        },
      })
    end
  end,
  opts_extend = { "spec" },
}
