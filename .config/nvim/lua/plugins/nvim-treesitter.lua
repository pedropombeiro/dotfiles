--  The goal of nvim-treesitter is both to provide a simple and easy way to use the interface for tree-sitter in Neovim
--    and to provide some basic functionality such as highlighting based on it:

return {
  {
    "nvim-treesitter/nvim-treesitter-context", -- Show code context
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    module = "treesitter-context",
    config = function(_, opts)
      ---@type pmsp.neovim.Config
      local config = require("config")
      local colors = config.theme.colors

      Set_hl({ ContextBottom = { underline = true, sp = colors.bg0_s } }, { prefix = "Treesitter", default = true })
      require("treesitter-context").setup(opts)
    end,
  },

  {
    "windwp/nvim-ts-autotag", -- Automatically add closing tags for HTML and JSX
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  {
    "andymass/vim-matchup",
    lazy = true, -- we let treesitter manage this
    init = function()
      vim.g.matchup_matchparen_deferred = 1
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    version = false, -- last release is way too old and doesn't work on Windows
    build = function()
      local ts_update = require("nvim-treesitter.install").update({ with_sync = true })
      ts_update()
    end,
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter-textobjects",
        config = function()
          -- When in diff mode, we want to use the default
          -- vim text objects c & C instead of the treesitter ones.
          local move = require("nvim-treesitter.textobjects.move") ---@type table<string,fun(...)>
          local configs = require("nvim-treesitter.configs")
          for name, fn in pairs(move) do
            if name:find("goto") == 1 then
              move[name] = function(q, ...)
                if vim.wo.diff then
                  local config = configs.get_module("textobjects.move")[name] ---@type table<string,string>
                  for key, query in pairs(config or {}) do
                    if q == query and key:find("[%]%[][cC]") then
                      vim.cmd("normal! " .. key)
                      return
                    end
                  end
                end
                return fn(q, ...)
              end
            end
          end
        end,
      },
      "RRethy/nvim-treesitter-endwise", --- Wisely add 'end' in Ruby, Vimscript, Lua, etc.
      {
        "HiPhish/rainbow-delimiters.nvim", -- Rainbow delimiters for Neovim with Tree-sitter
        main = "rainbow-delimiters.setup",
        opts = function()
          return {
            strategy = {
              [""] = require("rainbow-delimiters").strategy["global"],
              vim = require("rainbow-delimiters").strategy["local"],
            },
            query = {
              [""] = "rainbow-delimiters",
              lua = "rainbow-blocks",
            },
            highlight = {
              "MiniIconsRed",
              "MiniIconsYellow",
              "MiniIconsBlue",
              "MiniIconsOrange",
              "MiniIconsGreen",
              "MiniIconsPurple",
              "MiniIconsCyan",
            },
          }
        end,
      },
    },
    init = function(plugin)
      -- PERF: add nvim-treesitter queries to the rtp and its custom query predicates early
      -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
      -- no longer trigger the **nvim-treesitter** module to be loaded in time.
      -- Luckily, the only things that those plugins need are the custom queries, which we make available
      -- during startup.
      require("lazy.core.loader").add_to_rtp(plugin)
      require("nvim-treesitter.query_predicates")
    end,
    cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
    ---@type LazyKeysSpec[]
    keys = {
      { "<TAB>", desc = "Increment Selection" },
      { "<S-TAB>", desc = "Decrement Selection", mode = "x" },
    },
    main = "nvim-treesitter.configs",
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- A list of parser names, or "all"
      ensure_installed = {
        "bash",
        "diff",
        "dockerfile",
        "embedded_template",
        "git_config",
        "git_rebase",
        "gitcommit",
        "gitignore",
        "go",
        "gomod",
        "graphql",
        "html",
        "json",
        "lua",
        "make",
        "markdown",
        "markdown_inline",
        "python",
        "regex",
        "ruby",
        "sql",
        "ssh_config",
        "toml",
        "tmux",
        "vim",
        "vimdoc",
        "yaml",
      },
      -- Install parsers synchronously (only applied to `ensure_installed`)
      sync_install = false,
      -- Automatically install missing parsers when entering buffer
      -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
      auto_install = true,
      -- List of parsers to ignore installing (for "all")
      ignore_install = {
        "java",
      },
      endwise = {
        enable = true,
      },
      matchup = {
        enable = true,
      },
      highlight = {
        -- `false` will disable the whole extension
        enable = true,
        -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
        -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
        -- Using this option may slow down your editor, and you may see some duplicate highlights.
        -- Instead of true it can also be a list of languages
        additional_vim_regex_highlighting = false,
        disable = function(lang, bufnr) -- Disable in large buffers
          return lang == "just" or vim.api.nvim_buf_line_count(bufnr) > 5000
        end,
      },
      indent = { enable = true, disable = { "eruby", "html", "python", "css", "rust" } },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<CR>",
          scope_incremental = "<CR>",
          node_incremental = "<TAB>",
          node_decremental = "<S-TAB>",
        },
      },
      textobjects = {
        select = {
          enable = true,
          -- Automatically jump forward to textobj, similar to targets.vim
          lookahead = true,
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]m"] = "@function.outer",
            ["]]"] = { query = "@class.outer", desc = "Next class start" },
          },
          goto_next_end = {
            ["]M"] = "@function.outer",
            ["]["] = "@class.outer",
          },
          goto_previous_start = {
            ["[m"] = "@function.outer",
            ["[["] = "@class.outer",
          },
          goto_previous_end = {
            ["[M"] = "@function.outer",
            ["[]"] = "@class.outer",
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ["<leader>."] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>,"] = "@parameter.inner",
          },
        },
      },
    },
  },
}
