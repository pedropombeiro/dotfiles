return {
  --### Key mappings management

  --- 💥 Create key bindings that stick. WhichKey is a lua plugin for Neovim 0.5 that displays a popup with
  --- possible keybindings of the command you started typing.
  "folke/which-key.nvim",

  --### Buffer decorations
  "mtdl9/vim-log-highlighting", -- Provides syntax highlighting for generic log files in VIM.
  "lukas-reineke/indent-blankline.nvim", -- Indent guides for Neovim

  {
    "petertriho/nvim-scrollbar", -- Extensible Neovim Scrollbar
    dependencies = "lewis6991/gitsigns.nvim", -- Git integration for buffers
  },

  --### Search
  "junegunn/fzf", -- 🌸 A command-line fuzzy finder

  "tpope/vim-abolish", -- abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word

  --### Linting
  --- 🌈 Plugin that creates missing LSP diagnostics highlight groups for color schemes that don't yet support
  --- the Neovim 0.5 builtin LSP client
  "folke/lsp-colors.nvim",

  "arkav/lualine-lsp-progress", -- LSP Progress lualine component

  --### Snippets
  { "hrsh7th/vim-vsnip", lazy = true }, -- Snippet plugin for vim/nvim that supports LSP/VSCode's snippet format.

  --### Completion
  "gelguy/wilder.nvim", -- A more adventurous wildmenu autocomplete suggestions for : and /

  --### Highlights
  {
    "weilbith/nvim-code-action-menu", -- Pop-up menu for code actions to show meta-information and diff preview
    cmd = "CodeActionMenu"
  },

  --### Git
  {
    "rhysd/git-messenger.vim", -- Vim and Neovim plugin to reveal the commit messages under the cursor
    cmd = "GitMessenger",
    keys = "<leader>gm"
  },

  --- Single tabpage interface for easily cycling through diffs for all modified files for any git rev.
  { 'sindrets/diffview.nvim', dependencies = 'nvim-lua/plenary.nvim' },
  "ruanyl/vim-gh-line", -- vim plugin that open the link of current line on github

  --### DAP
  {
    --- An extension for nvim-dap providing configurations for launching go debugger (delve)
    --- and debugging individual tests
    "leoluz/nvim-dap-go",
    config = true,
    dependencies = "mfussenegger/nvim-dap",
    ft = "go",
  },
  {
    "suketa/nvim-dap-ruby", -- An extension for nvim-dap providing configurations for launching debug.rb
    config = true,
    dependencies = "mfussenegger/nvim-dap",
    ft = "ruby",
  },

  --### Session management
  "farmergreg/vim-lastplace", -- Intelligently reopen files at your last edit position in Vim.

  --### Editor enhancements
  "junegunn/vim-easy-align", -- 🌻 A Vim alignment plugin
  "AndrewRadev/splitjoin.vim", -- Switch between single-line and multiline forms of code
  --- Wisely add 'end' in Ruby, Vimscript, Lua, etc. Tree-sitter aware alternative to tpope's vim-endwise
  "RRethy/nvim-treesitter-endwise",
  { "tpope/vim-repeat", event = "VeryLazy" }, -- repeat.vim: enable repeating supported plugin maps with '.'
  "tpope/vim-speeddating", -- speeddating.vim: C,TRL-A/CTRL-X to increment dates, times, and more
  { "tpope/vim-surround", event = "VeryLazy" }, -- surround.vim: Delete/change/add parentheses/quotes/XML-tags/much more with ease
  "tpope/vim-unimpaired", -- unimpaired.vim: Pairs of handy bracket mappings

  --### Other
  "tmux-plugins/vim-tmux", -- Vim plugin for .tmux.conf
  {
    "tpope/vim-dispatch", -- dispatch.vim: Asynchronous build and test dispatcher
    cmd = { "Dispatch", "Make", "Focus", "Start" }
  },
  "tpope/vim-eunuch", -- eunuch.vim: Helpers for UNIX
  "tpope/vim-sensible", -- sensible.vim: Defaults everyone can agree on
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
    ft = "markdown",
    build = function() vim.fn["mkdp#util#install"]() end, -- install without yarn or npm
  },
}
