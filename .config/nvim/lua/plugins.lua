local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({ "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path })
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

local function get_config(name)
  return string.format('require("config/%s")', name)
end

-- check if firenvim is active
local firenvim_active = function()
  return vim.g.started_by_firenvim
end

local firenvim_not_active = function()
  return not vim.g.started_by_firenvim
end

-- configure Neovim to automatically run :PackerCompile whenever plugins.lua is updated
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

-- disable netrw at the very start of init.lua
--  (strongly advised so that nvim-tree can take over directory loading)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

return require("packer").startup({ function(use)
  -- Packer can manage itself
  use "wbthomason/packer.nvim"

  use "AndrewRadev/splitjoin.vim" -- Switch between single-line and multiline forms of code
  use {
    "editorconfig/editorconfig-vim", -- EditorConfig plugin for Vim
    config = get_config("editorconfig-vim")
  }

  -- Buffer decorations
  use "mtdl9/vim-log-highlighting" -- Provides syntax highlighting for generic log files in VIM.
  use {
    "yamatsum/nvim-cursorline", -- A plugin for neovim that highlights cursor words and lines
    config = get_config("nvim-cursorline"),
  }
  use "lukas-reineke/indent-blankline.nvim" -- Indent guides for Neovim

  -- File management
  use {
    "francoiscabrol/ranger.vim", -- Ranger integration in vim and neovim
    config = get_config("ranger"),
    opt = true,
    cmd = { "Ranger", "RangerWorkingDirectory" },
    keys = "<leader>R",
    requires = "rbgrouleff/bclose.vim" -- The BClose Vim plugin for deleting a buffer without closing the window
  }
  use {
    "nvim-tree/nvim-tree.lua", -- A File Explorer For Neovim Written In Lua
    cond = firenvim_not_active,
    requires = "kyazdani42/nvim-web-devicons",
    config = get_config("nvim-tree"),
  }

  -- Search
  use "junegunn/fzf" -- 🌸 A command-line fuzzy finder
  use {
    "junegunn/fzf.vim", -- fzf ❤️ vim
    config = get_config("fzf-vim")
  }
  use "tpope/vim-abolish" -- abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word

  -- Linting
  use "folke/lsp-colors.nvim" -- 🌈 Plugin that creates missing LSP diagnostics highlight groups for color schemes that don't yet support the Neovim 0.5 builtin LSP client.
  use {
    "folke/trouble.nvim", -- 🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all the trouble your code is causing.
    requires = {
      { "kyazdani42/nvim-web-devicons", opt = true }
    },
    config = get_config("trouble")
  }

  local mason = {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end
  }
  local mason_lspconfig = {
    -- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
    -- to use to launch those servers.
    "williamboman/mason-lspconfig.nvim",
    requires = { mason },
  }
  use {
    "junnplus/lsp-setup.nvim", -- A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.
    config = get_config("lsp-setup"),
    requires = {
      {
        "neovim/nvim-lspconfig", -- Quickstart configs for Nvim LSP
        requires = {
          "hrsh7th/cmp-nvim-lsp", -- nvim-cmp source for neovim builtin LSP client
          mason_lspconfig,
          "b0o/schemastore.nvim", -- 🛍 JSON schemas for Neovim
        },
      },
      mason_lspconfig
    },
  }

  use {
    "j-hui/fidget.nvim", -- Standalone UI for nvim-lsp progress
    config = function()
      require("fidget").setup {}
    end
  }

  use {
    "jayp0521/mason-null-ls.nvim", -- mason-null-ls bridges mason.nvim with the null-ls plugin - making it easier to use both plugins together.
    config = get_config("mason-null-ls"),
    requires = {
      {
        "jose-elias-alvarez/null-ls.nvim", -- Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.
        config = get_config("null-ls"),
        requires = {
          "nvim-lua/plenary.nvim" -- plenary: full; complete; entire; absolute; unqualified. All the lua functions I don't want to write twice.
        }
      },
      mason,
    }
  }

  -- Snippets
  use { "L3MON4D3/LuaSnip", opt = true } -- Snippet Engine for Neovim written in Lua.

  -- Completion
  use {
    "hrsh7th/nvim-cmp", -- A completion plugin for neovim coded in Lua.
    requires = {
      { "hrsh7th/cmp-buffer", after = "nvim-cmp" }, -- nvim-cmp source for buffer words
      { "hrsh7th/cmp-nvim-lsp", after = "nvim-cmp" }, -- nvim-cmp source for neovim builtin LSP client
      { "hrsh7th/cmp-path", after = "nvim-cmp" }, -- nvim-cmp source for path
      { "saadparwaiz1/cmp_luasnip", after = "nvim-cmp" }, -- luasnip completion source for nvim-cmp
      { "hrsh7th/cmp-cmdline", after = "nvim-cmp" }, -- nvim-cmp source for vim's cmdline
    },
    config = get_config("nvim-cmp"),
    event = "InsertEnter",
    wants = "LuaSnip",
  }

  -- Highlights
  use {
    "nvim-treesitter/nvim-treesitter", -- Nvim Treesitter configurations and abstraction layer
    run = function()
      local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
      ts_update()
    end,
    config = get_config("nvim-treesitter"),
  }

  -- Git
  use {
    "kdheepak/lazygit.nvim", -- Plugin for calling lazygit from within neovim.
    config = get_config("lazygit"),
  }

  use {
    "lewis6991/gitsigns.nvim", -- Git integration for buffers
    requires = { "nvim-lua/plenary.nvim" },
    config = get_config("gitsigns"),
  }

  use "sindrets/diffview.nvim" -- Single tabpage interface for easily cycling through diffs for all modified files for any git rev.
  use "ruanyl/vim-gh-line" -- vim plugin that open the link of current line on github
  use {
    "tpope/vim-fugitive", -- fugitive.vim: A Git wrapper so awesome, it should be illegal
    config = get_config("vim-fugitive")
  }

  -- Color scheme
  use {
    "themercorp/themer.lua", -- A simple, minimal highlighter plugin for neovim
    config = get_config("themer")
  }

  -- Session management
  use "farmergreg/vim-lastplace" -- Intelligently reopen files at your last edit position in Vim.
  use {
    "rmagatti/auto-session", -- A small automated session manager for Neovim
    config = get_config("auto-session")
  }

  -- Editor enhancements
  use {
    "junegunn/vim-easy-align", -- 🌻 A Vim alignment plugin
    config = get_config("vim-easy-align")
  }
  use {
    "nishigori/increment-activator", -- Vim Plugin for enhance to increment candidates U have defined.
    config = get_config("increment-activator")
  }
  use "preservim/nerdcommenter" -- Vim plugin for intensely nerdy commenting powers
  use "tpope/vim-commentary" -- commentary.vim: comment stuff out
  use "RRethy/nvim-treesitter-endwise" -- Wisely add 'end' in Ruby, Vimscript, Lua, etc. Tree-sitter aware alternative to tpope's vim-endwise

  use "tpope/vim-repeat" -- repeat.vim: enable repeating supported plugin maps with '.'
  use "tpope/vim-speeddating" -- speeddating.vim: use CTRL-A/CTRL-X to increment dates, times, and more
  use "tpope/vim-surround" -- surround.vim: Delete/change/add parentheses/quotes/XML-tags/much more with ease
  use "tpope/vim-unimpaired" -- unimpaired.vim: Pairs of handy bracket mappings

  -- Other
  use "skywind3000/asyncrun.vim" -- 🚀 Run Async Shell Commands in Vim 8.0 / NeoVim and Output to the Quickfix Window !!
  use "tmux-plugins/vim-tmux" -- Vim plugin for .tmux.conf
  use {
    "tpope/vim-dispatch", -- dispatch.vim: Asynchronous build and test dispatcher
    opt = true,
    cmd = { "Dispatch", "Make", "Focus", "Start" }
  }
  use "tpope/vim-eunuch" -- eunuch.vim: Helpers for UNIX
  use "tpope/vim-sensible" -- sensible.vim: Defaults everyone can agree on
  use "tpope/vim-sleuth" -- sleuth.vim: Heuristically set buffer options
  use {
    "tpope/vim-bundler", -- bundler.vim: Lightweight support for Ruby's Bundler
    opt = true,
    ft = "ruby",
    cmd = { "Bundle", "Bopen", "Bsplit", "Btabedit" }
  }
  use { "tpope/vim-rails", ft = "ruby" } -- rails.vim: Ruby on Rails power tools
  use {
    "bfontaine/Brewfile.vim", -- Brewfile syntax for Vim
    opt = true,
    ft = "ruby"
  }
  use {
    "nvim-neotest/neotest", -- An extensible framework for interacting with tests within NeoVim.
    config = get_config("neotest"),
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",

      "nvim-neotest/neotest-go",
      "olimorris/neotest-rspec",
    }
  }
  use "wsdjeg/vim-fetch" -- Make Vim handle line and column numbers in file names with a minimum of fuss

  use {
    "glacambre/firenvim", -- Embed Neovim in Chrome, Firefox & others.
    run = function() vim.fn["firenvim#install"](0) end,
    opt = true,
    cond = firenvim_active,
    config = get_config("firenvim")
  }

  -- Buffer management
  use {
    "nvim-lualine/lualine.nvim", -- A blazing fast and easy to configure neovim statusline plugin written in pure lua.
    cond = firenvim_not_active,
    requires = { "kyazdani42/nvim-web-devicons", opt = true },
    config = get_config("lualine")
  }
  use {
    "kdheepak/tabline.nvim",
    cond = firenvim_not_active,
    config = function()
      require "tabline".setup {}
      vim.cmd [[
        set guioptions-=e " Use showtabline in gui vim
        set sessionoptions+=tabpages,globals " store tabpages and globals in session
      ]]
    end,
    requires = {
      { "nvim-lualine/lualine.nvim", opt = true }, -- A blazing fast and easy to configure neovim statusline plugin written in pure lua.
      { "kyazdani42/nvim-web-devicons", opt = true }
    }
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require("packer").sync()
  end
end,
  config = {
    display = {
      open_fn = function()
        return require("packer.util").float({ border = "single" })
      end
    }
  } })
