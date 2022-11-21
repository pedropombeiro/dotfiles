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
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
    autocmd BufWritePost ~/.config/nvim/lua/config/*.lua source <afile> | PackerCompile
  augroup end
]])

-- disable netrw at the very start of init.lua
--  (strongly advised so that nvim-tree can take over directory loading)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- https://github.com/wbthomason/packer.nvim#packernvim
return require("packer").startup({ function(use)
  local function with_default_config(module_name, use_params)
    if type(use_params) ~= "table" then
      use_params = { use_params }
    end

    use_params["config"] = string.format('require("%s").setup()', module_name)

    return use_params
  end

  local function with_config(use_params)
    local plugin_name
    if type(use_params) == "table" then
      plugin_name = use_params[1]
    else
      plugin_name = use_params
      use_params = { plugin_name }
    end

    local config_file = string.match(plugin_name, "^.*/([a-z-_]+)")
    use_params["config"] = string.format('require("config/%s")', config_file)

    return use_params
  end

  -- Packer can manage itself
  use "wbthomason/packer.nvim"

  use 'lewis6991/impatient.nvim'

  -- Buffer decorations
  use "mtdl9/vim-log-highlighting" -- Provides syntax highlighting for generic log files in VIM.
  use(with_config "yamatsum/nvim-cursorline") -- A plugin for neovim that highlights cursor words and lines

  use "lukas-reineke/indent-blankline.nvim" -- Indent guides for Neovim

  -- File management
  use(with_config {
    "francoiscabrol/ranger.vim", -- Ranger integration in vim and neovim
    opt = true,
    cmd = { "Ranger", "RangerWorkingDirectory" },
    keys = "<leader>R",
    requires = "rbgrouleff/bclose.vim" -- The BClose Vim plugin for deleting a buffer without closing the window
  })
  use(with_config {
    "nvim-tree/nvim-tree.lua", -- A File Explorer For Neovim Written In Lua
    opt = true,
    keys = "<C-\\>",
    cmd = { "NvimTreeOpen", "NvimTreeClose", "NvimTreeFocus", "NvimTreeResize", "NvimTreeToggle", "NvimTreeRefresh",
      "NvimTreeCollapse", "NvimTreeFindFile", "NvimTreeFindFileToggle" },
    cond = firenvim_not_active,
    requires = "kyazdani42/nvim-web-devicons",
  })

  -- Search
  use "junegunn/fzf" -- 🌸 A command-line fuzzy finder
  use(with_config "junegunn/fzf.vim") -- fzf ❤️ vim

  use "tpope/vim-abolish" -- abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word

  -- Linting
  use "folke/lsp-colors.nvim" -- 🌈 Plugin that creates missing LSP diagnostics highlight groups for color schemes that don't yet support the Neovim 0.5 builtin LSP client.
  use(with_config {
    "folke/trouble.nvim", -- 🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all the trouble your code is causing.
    requires = {
      { "kyazdani42/nvim-web-devicons", opt = true }
    },
  })

  local mason = with_default_config("mason", "williamboman/mason.nvim")
  local mason_lspconfig = {
    -- uses Mason to ensure installation of user specified LSP servers and will tell nvim-lspconfig what command
    -- to use to launch those servers.
    "williamboman/mason-lspconfig.nvim",
    requires = { mason },
  }
  use(with_config {
    "junnplus/lsp-setup.nvim", -- A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.
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
  })

  use(with_default_config("fidget", "j-hui/fidget.nvim")) -- Standalone UI for nvim-lsp progress

  use(with_config {
    "jayp0521/mason-null-ls.nvim", -- mason-null-ls bridges mason.nvim with the null-ls plugin - making it easier to use both plugins together.
    requires = {
      {
        "jose-elias-alvarez/null-ls.nvim", -- Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.
        requires = {
          "nvim-lua/plenary.nvim" -- plenary: full; complete; entire; absolute; unqualified. All the lua functions I don't want to write twice.
        }
      },
      mason,
    }
  })

  use(with_config {
    "simrat39/symbols-outline.nvim", -- A tree like view for symbols in Neovim using the Language Server Protocol. Supports all your favourite languages.
    cmd = "SymbolsOutline",
    keys = "<C-'>"
  })

  use(with_config "mfussenegger/nvim-lint") -- An asynchronous linter plugin for Neovim complementary to the built-in Language Server Protocol support.

  use(with_config "https://git.sr.ht/~whynothugo/lsp_lines.nvim") -- lsp_lines is a simple neovim plugin that renders diagnostics using virtual lines on top of the real line of code.

  -- Snippets
  use { "L3MON4D3/LuaSnip", opt = true } -- Snippet Engine for Neovim written in Lua.

  -- Completion
  use(with_config {
    "hrsh7th/nvim-cmp", -- A completion plugin for neovim coded in Lua.
    requires = {
      { "hrsh7th/cmp-buffer", after = "nvim-cmp" }, -- nvim-cmp source for buffer words
      { "hrsh7th/cmp-nvim-lsp", after = "nvim-cmp" }, -- nvim-cmp source for neovim builtin LSP client
      { "hrsh7th/cmp-path", after = "nvim-cmp" }, -- nvim-cmp source for path
      { "saadparwaiz1/cmp_luasnip", after = "nvim-cmp" }, -- luasnip completion source for nvim-cmp
      { "hrsh7th/cmp-cmdline", after = "nvim-cmp" }, -- nvim-cmp source for vim's cmdline
    },
    event = "InsertEnter",
    wants = "LuaSnip",
  })

  -- Highlights
  use(with_config {
    "nvim-treesitter/nvim-treesitter", -- Nvim Treesitter configurations and abstraction layer
    run = function()
      local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
      ts_update()
    end,
  })

  use(with_config {
    "kosayoda/nvim-lightbulb", -- VSCode 💡 for neovim's built-in LSP.
    requires = "antoinemadec/FixCursorHold.nvim",
  })
  use(with_config {
    "weilbith/nvim-code-action-menu", -- Pop-up menu for code actions to show meta-information and diff preview
    cmd = "CodeActionMenu",
    keys = "<leader>la"
  })

  -- Git
  use(with_config "kdheepak/lazygit.nvim") -- Plugin for calling lazygit from within neovim.

  use(with_config {
    "lewis6991/gitsigns.nvim", -- Git integration for buffers
    requires = { "nvim-lua/plenary.nvim" },
  })

  use "sindrets/diffview.nvim" -- Single tabpage interface for easily cycling through diffs for all modified files for any git rev.
  use "ruanyl/vim-gh-line" -- vim plugin that open the link of current line on github
  use(with_config "tpope/vim-fugitive") -- fugitive.vim: A Git wrapper so awesome, it should be illegal

  -- DAP
  use(with_config {
    "mfussenegger/nvim-dap", -- Debug Adapter Protocol client implementation for Neovim
    opt = true,
    keys = {
      "<S-F5>",
      "<F5>",
      "<F7>",
      "<F8>",
      "<F9>",
    },
    run = ":MasonInstall bash-debug-adapter",
    requires = {
      with_default_config("nvim-dap-virtual-text", {
        "theHamsta/nvim-dap-virtual-text",
        requires = "nvim-treesitter/nvim-treesitter",
      }),
      with_config("rcarriga/nvim-dap-ui"),
    }
  })
  use {
    "leoluz/nvim-dap-go", -- An extension for nvim-dap providing configurations for launching go debugger (delve) and debugging individual tests
    config = function()
      vim.cmd([[ PackerLoad nvim-dap ]])
      require("dap-go").setup()
    end,
    opt = true,
    requires = "mfussenegger/nvim-dap",
    ft = "go",
    run = ":MasonInstall delve go-debug-adapter",
  }
  use {
    "suketa/nvim-dap-ruby", -- An extension for nvim-dap providing configurations for launching debug.rb
    config = function()
      vim.cmd([[ PackerLoad nvim-dap ]])
      require("dap-ruby").setup()
    end,
    opt = true,
    requires = "mfussenegger/nvim-dap",
    ft = "ruby",
  }

  -- Color scheme
  use(with_config "themercorp/themer.lua") -- A simple, minimal highlighter plugin for neovim

  -- Session management
  use "farmergreg/vim-lastplace" -- Intelligently reopen files at your last edit position in Vim.
  use(with_config "rmagatti/auto-session") -- A small automated session manager for Neovim

  -- Editor enhancements
  use(with_config "junegunn/vim-easy-align") -- 🌻 A Vim alignment plugin
  use(with_config "nishigori/increment-activator") -- Vim Plugin for enhance to increment candidates U have defined.
  use "AndrewRadev/splitjoin.vim" -- Switch between single-line and multiline forms of code
  use(with_config "editorconfig/editorconfig-vim") -- EditorConfig plugin for Vim
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
  use(with_config {
    "nvim-neotest/neotest", -- An extensible framework for interacting with tests within NeoVim.
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",

      "nvim-neotest/neotest-go",
      "olimorris/neotest-rspec",
    }
  })
  use "wsdjeg/vim-fetch" -- Make Vim handle line and column numbers in file names with a minimum of fuss

  use(with_config {
    "glacambre/firenvim", -- Embed Neovim in Chrome, Firefox & others.
    run = function() vim.fn["firenvim#install"](0) end,
    opt = true,
    cond = firenvim_active,
  })

  -- Buffer management
  use(with_config {
    "nvim-lualine/lualine.nvim", -- A blazing fast and easy to configure neovim statusline plugin written in pure lua.
    requires = { "kyazdani42/nvim-web-devicons", opt = true },
  })
  use(with_config {
    "kdheepak/tabline.nvim",
    cond = firenvim_not_active,
    requires = {
      { "nvim-lualine/lualine.nvim", opt = true }, -- A blazing fast and easy to configure neovim statusline plugin written in pure lua.
      { "kyazdani42/nvim-web-devicons", opt = true }
    }
  })

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
