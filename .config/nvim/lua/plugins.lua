return {
  --### Buffer decorations
  {
    "mtdl9/vim-log-highlighting", -- Provides syntax highlighting for generic log files in VIM.
    ft = "log",
  },
  {
    "grafana/vim-alloy", -- Provides syntax highlighting for alloy files
    ft = "alloy",
  },
  {
    "hat0uma/csvview.nvim",
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
    ft = {
      "csv",
      "tsv",
      "csv_semicolon",
      "csv_whitespace",
      "csv_pipe",
      "rfc_csv",
      "rfc_semicolon",
    },
    ---@module "csvview"
    ---@type CsvView.Options
    opts = function()
      Snacks.toggle
        .new({
          id = "csv",
          name = "CsvView",
          get = function() return require("csvview").is_enabled() end,
          set = function(_state) vim.cmd(string.format("CsvViewToggle display_mode=border header_lnum=1")) end,
          icon = {
            enabled = " ",
            disabled = " ",
          },
          color = {
            enabled = "green",
            disabled = "yellow",
          },
          wk_desc = {
            enabled = "Disable ",
            disabled = "Enable ",
          },
        })
        :map("<leader>ux")

      return {
        parser = { comments = { "#", "//" } },
        keymaps = {
          -- Text objects for selecting fields
          textobject_field_inner = { "if", mode = { "o", "x" } },
          textobject_field_outer = { "af", mode = { "o", "x" } },
          -- Excel-like navigation:
          -- Use <Tab> and <S-Tab> to move horizontally between fields.
          -- Use <Enter> and <S-Enter> to move vertically between rows and place the cursor at the end of the field.
          -- Note: In terminals, you may need to enable CSI-u mode to use <S-Tab> and <S-Enter>.
          jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
          jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
          jump_next_row = { "<Enter>", mode = { "n", "v" } },
          jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
        },
      }
    end,
  },
  {
    "meanderingprogrammer/render-markdown.nvim",
    cmd = { "RenderMarkdown" },
    ft = { "markdown", "norg", "rmd", "org", "codecompanion" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
    opts = {
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      heading = {
        sign = false,
        icons = {},
      },
      checkbox = {
        enabled = false,
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      Snacks.toggle({
        name = "Render Markdown",
        get = require("render-markdown").get,
        set = require("render-markdown").set,
      }):map("<leader>um")
    end,
  },

  {
    "petertriho/nvim-scrollbar", -- Extensible Neovim Scrollbar
    event = { "BufNewFile", "BufReadPost" },
    opts = {
      excluded_buftypes = {
        "nofile",
      },
    },
    specs = {
      {
        "lewis6991/gitsigns.nvim",
        opts = function() require("scrollbar.handlers.gitsigns").setup() end,
      },
    },
  },

  --### Search
  {
    "tpope/vim-abolish", -- abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word
    event = "BufReadPost",
  },
  {
    "MagicDuck/grug-far.nvim", -- Find And Replace plugin for neovim
    cmd = { "GrugFar", "GrugFarWithin" },
    opts = { headerMaxWidth = 80 },
  },

  --### Navigation
  {
    "ruanyl/vim-gh-line", -- vim plugin that open the link of current line on github
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      { "<leader>gb", "<Plug>(gh-line-blame)", desc = "Open blame view in browser" },
      { "<leader>gf", "<Plug>(gh-line)", desc = "Open blob view in browser" },
      { "<leader>go", "<Plug>(gh-repo)", desc = "Open in browser" },
    },
  },

  --### Session management
  {
    "farmergreg/vim-lastplace", -- Intelligently reopen files at your last edit position in Vim.
    event = "BufReadPre",
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = { options = vim.opt.sessionoptions:get() },
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      {
        "<leader>qs",
        function() require("persistence").load() end,
        desc = "Restore session",
      },
      {
        "<leader>ql",
        function() require("persistence").load({ last = true }) end,
        desc = "Restore last session",
      },
      {
        "<leader>qd",
        function() require("persistence").stop() end,
        desc = "Don't save current session",
      },
    },
  },

  --### Editor enhancements
  {
    "ejrichards/mise.nvim",
    opts = {},
  },
  {
    "sitiom/nvim-numbertoggle", -- Neovim plugin to automatically toggle between relative and absolute line numbers.
    event = "BufReadPost",
  },
  {
    "Wansmer/treesj", -- Neovim plugin for splitting/joining blocks of code
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      { "gJ", ":TSJJoin<CR>", desc = "Join into single-line form" },
      { "gS", ":TSJSplit<CR>", desc = "Split into multi-line form" },
    },
    opts = {
      use_default_keymaps = false,
    },
  },
  {
    "tpope/vim-repeat", -- repeat.vim: enable repeating supported plugin maps with '.'
    keys = ".",
  },
  {
    "nvim-mini/mini.surround",
    version = false,
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
    specs = {
      {
        "folke/which-key.nvim",
        opts = {
          ---@module "which-key"
          ---@type wk.Spec
          spec = {
            { "gs", group = "Surround", icon = "" },
          },
        },
      },
    },
  },
  { "tummetott/unimpaired.nvim", event = { "BufReadPre", "BufNewFile" }, opts = {} }, -- LUA port of tpope's famous vim-unimpaired plugin
  { "RaafatTurki/hex.nvim", event = { "BufReadPre", "BufNewFile" }, opts = {} }, -- hex editing done right
  { "guns/xterm-color-table.vim", config = true, cmd = "XtermColorTable" }, -- All 256 xterm colors with their RGB equivalents, right in Vim!


  --### Other
  { "tmux-plugins/vim-tmux", ft = "tmux" }, -- Vim plugin for .tmux.conf
  {
    "tpope/vim-eunuch", -- eunuch.vim: Helpers for UNIX
    cmd = {
      "Remove",
      "Delete",
      "Move",
      "Chmod",
      "Mkdir",
      "Cfind",
      "Clocate",
      "Lfind",
      "Llocate",
      "Wall",
      "SudoWrite",
      "SudoEdit",
    },
  },
  {
    "tpope/vim-sleuth", -- sleuth.vim: Heuristically set buffer options
    event = "BufReadPre",
  },
  {
    "tpope/vim-bundler", -- bundler.vim: Lightweight support for Ruby's Bundler
    ft = "ruby",
    cmd = { "Bundle", "Bopen", "Bsplit", "Btabedit" },
  },
  "tpope/vim-projectionist", -- Granular project configuration
  { "tpope/vim-rails", ft = "ruby" }, -- rails.vim: Ruby on Rails power tools
  { "bfontaine/Brewfile.vim", ft = "ruby" }, -- Brewfile syntax for Vim
  "wsdjeg/vim-fetch", -- Make Vim handle line and column numbers in file names with a minimum of fuss

  {
    "iamcco/markdown-preview.nvim", -- markdown preview plugin for (neo)vim
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = "markdown",
    cond = function() return vim.env.SSH_CONNECTION == nil end,
    build = "cd app && yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
  },

  { "NoahTheDuke/vim-just", event = { "BufReadPre", "BufNewFile" }, ft = "just" },

  {
    "ruifm/gitlinker.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      {
        "<leader>gy",
        function()
          require("gitlinker").get_buf_range_url(
            "n",
            { action_callback = require("gitlinker.actions").open_in_browser }
          )
        end,
        mode = "n",
        desc = "Yank Git URL",
        silent = true,
      },
      {
        "<leader>gy",
        function()
          require("gitlinker").get_buf_range_url(
            "v",
            { action_callback = require("gitlinker.actions").open_in_browser }
          )
        end,
        mode = "v",
        desc = "Yank Git URL",
      },
    },
    opts = {
      mappings = nil,
    },
  },
}
