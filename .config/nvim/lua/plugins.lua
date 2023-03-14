return {
  --### Buffer decorations
  {
    "mtdl9/vim-log-highlighting", -- Provides syntax highlighting for generic log files in VIM.
    ft = "log",
  },

  {
    "petertriho/nvim-scrollbar",              -- Extensible Neovim Scrollbar
    dependencies = "lewis6991/gitsigns.nvim", -- Git integration for buffers
    event = "BufReadPost",
  },

  --### Search
  {
    "tpope/vim-abolish", -- abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word
    event = "BufReadPost",
  },

  --### Snippets
  { "hrsh7th/vim-vsnip", lazy = true }, -- Snippet plugin for vim/nvim that supports LSP/VSCode's snippet format.
  {
    "rafamadriz/friendly-snippets",
    ft = { "dockerfile", "go", "lua", "ruby" },
    init = function()
      vim.g.vsnip_filetypes = {
        ruby = { "rails" }
      }
    end
  },

  --### Navigation
  {
    "ruanyl/vim-gh-line", -- vim plugin that open the link of current line on github
    keys = {
      { "<leader>gb", "<Plug>(gh-line-blame)", desc = "Open blame view in browser" },
      { "<leader>gh", "<Plug>(gh-line)",       desc = "Open blob view in browser" },
      { "<leader>go", "<Plug>(gh-repo)",       desc = "Open in browser" },
    }
  },

  --### Session management
  {
    "farmergreg/vim-lastplace", -- Intelligently reopen files at your last edit position in Vim.
    event = "BufReadPre",
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = { options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals" } },
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").load() end,                desc = "Restore session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end,                desc = "Don't save current session" },
    },
  },

  --### Editor enhancements
  {
    "Wansmer/treesj", -- Neovim plugin for splitting/joining blocks of code
    keys = {
      { "gJ", ":TSJJoin<CR>",  desc = "Join into single-line form" },
      { "gS", ":TSJSplit<CR>", desc = "Split into multi-line form" },
    },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      use_default_keymaps = false,
    },
  },
  { "tpope/vim-repeat",  keys = "." }, -- repeat.vim: enable repeating supported plugin maps with '.'
  {
    "tpope/vim-speeddating",           -- speeddating.vim: CTRL-A/CTRL-X to increment dates, times, and more
    event = "BufReadPost",
  },
  {
    "tpope/vim-surround", -- surround.vim: Delete/change/add parentheses/quotes/XML-tags/much more with ease
    event = "BufReadPost",
  },
  { 'tummetott/unimpaired.nvim', config = true }, -- LUA port of tpope's famous vim-unimpaired plugin

  --### Other
  { "tmux-plugins/vim-tmux",     ft = "tmux" }, -- Vim plugin for .tmux.conf
  {
    "tpope/vim-dispatch",                       -- dispatch.vim: Asynchronous build and test dispatcher
    cmd = { "Dispatch", "Make", "Focus", "Start" }
  },
  {
    "tpope/vim-eunuch", -- eunuch.vim: Helpers for UNIX
    cmd = {
      "Remove", "Delete", "Move", "Chmod", "Mkdir", "Cfind", "Clocate", "Lfind", "Llocate", "Wall", "SudoWrite",
      "SudoEdit"
    }
  },
  {
    "tpope/vim-sleuth", -- sleuth.vim: Heuristically set buffer options
    event = "BufReadPre",
  },
  {
    "tpope/vim-bundler", -- bundler.vim: Lightweight support for Ruby's Bundler
    ft = "ruby",
    cmd = { "Bundle", "Bopen", "Bsplit", "Btabedit" }
  },
  { "tpope/vim-rails",        ft = "ruby" }, -- rails.vim: Ruby on Rails power tools
  { "bfontaine/Brewfile.vim", ft = "ruby" }, -- Brewfile syntax for Vim
  "wsdjeg/vim-fetch",                        -- Make Vim handle line and column numbers in file names with a minimum of fuss

  {
    "iamcco/markdown-preview.nvim",                       -- markdown preview plugin for (neo)vim
    ft = "markdown",
    build = function() vim.fn["mkdp#util#install"]() end, -- install without yarn or npm
  },

  { 'NoahTheDuke/vim-just', ft = "just" }
}
