return {
  --### Key mappings management

  --### Buffer decorations
  "mtdl9/vim-log-highlighting", -- Provides syntax highlighting for generic log files in VIM.

  {
    "petertriho/nvim-scrollbar", -- Extensible Neovim Scrollbar
    dependencies = "lewis6991/gitsigns.nvim", -- Git integration for buffers
    event = "BufReadPost",
  },

  --### Search
  "tpope/vim-abolish", -- abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word

  --### Linting
  --- 🌈 Plugin that creates missing LSP diagnostics highlight groups for color schemes that don't yet support
  --- the Neovim 0.5 builtin LSP client
  "folke/lsp-colors.nvim",

  "arkav/lualine-lsp-progress", -- LSP Progress lualine component

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

  --### Completion
  { "gelguy/wilder.nvim", config = true }, -- A more adventurous wildmenu autocomplete suggestions for : and /

  "ruanyl/vim-gh-line", -- vim plugin that open the link of current line on github

  --### Session management
  "farmergreg/vim-lastplace", -- Intelligently reopen files at your last edit position in Vim.

  --### Editor enhancements
  { "AndrewRadev/splitjoin.vim", keys = { "gS", "gJ" } }, -- Switch between single-line and multiline forms of code
  { "tpope/vim-repeat", keys = "." }, -- repeat.vim: enable repeating supported plugin maps with '.'
  "tpope/vim-speeddating", -- speeddating.vim: C,TRL-A/CTRL-X to increment dates, times, and more
  {
    "tpope/vim-surround", -- surround.vim: Delete/change/add parentheses/quotes/XML-tags/much more with ease
    event = "VeryLazy",
  },

  --### Other
  "tmux-plugins/vim-tmux", -- Vim plugin for .tmux.conf
  {
    "tpope/vim-dispatch", -- dispatch.vim: Asynchronous build and test dispatcher
    cmd = { "Dispatch", "Make", "Focus", "Start" }
  },
  "tpope/vim-eunuch", -- eunuch.vim: Helpers for UNIX
  "tpope/vim-sleuth", -- sleuth.vim: Heuristically set buffer options
  {
    "tpope/vim-bundler", -- bundler.vim: Lightweight support for Ruby's Bundler
    ft = "ruby",
    cmd = { "Bundle", "Bopen", "Bsplit", "Btabedit" }
  },
  { "tpope/vim-rails", ft = "ruby" }, -- rails.vim: Ruby on Rails power tools
  { "bfontaine/Brewfile.vim", ft = "ruby" }, -- Brewfile syntax for Vim
  "wsdjeg/vim-fetch", -- Make Vim handle line and column numbers in file names with a minimum of fuss

  {
    "iamcco/markdown-preview.nvim", -- markdown preview plugin for (neo)vim
    cmd = { "MarkdownPreview", "MarkdownPreviewToggle" },
    build = function() vim.fn["mkdp#util#install"]() end, -- install without yarn or npm
  },
}
