-- nvim-treesitter.vim (https://github.com/nvim-treesitter/nvim-treesitter)
--  Nvim Treesitter configurations and abstraction layer
--  The goal of nvim-treesitter is both to provide a simple and easy way to use the interface for tree-sitter in Neovim
--    and to provide some basic functionality such as highlighting based on it:

local status_ok, configs = pcall(require, "nvim-treesitter.configs")
if not status_ok then
  return
end

configs.setup {
  -- A list of parser names, or "all"
  ensure_installed = {
    "bash",
    "diff",
    "dockerfile",
    "git_rebase",
    "gitignore",
    "go",
    "gomod",
    "json",
    "help",
    "html",
    "lua",
    "make",
    "markdown",
    "markdown_inline",
    "python",
    "regex",
    "ruby",
    "sql",
    "toml",
    "vim",
    "yaml"
  },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = false,

  -- List of parsers to ignore installing (for "all")
  ignore_install = {
    "java",
    "javascript"
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
      if lang == "markdown" then
        return true
      end

      return vim.api.nvim_buf_line_count(bufnr) > 5000
    end,

    -- additional_vim_regex_highlighting = true,
    indent = { enable = true, disable = { "python", "css", "rust" } },
  },
  autotag = {
    enable = true,
    disable = { "xml", "markdown" },
  },
  endwise = {
    enable = true,
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
        ["ic"] = "@class.inner"
      }
    },
    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]]"] = "@class.outer"
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]["] = "@class.outer"
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[["] = "@class.outer"
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[]"] = "@class.outer"
      }
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
}

local opt = vim.opt

opt.foldenable = false -- Disable folding at startup.
-- vim.opt.foldmethod = "expr"
-- vim.opt.foldexpr   = "nvim_treesitter#foldexpr()"
---WORKAROUND
vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufNew", "BufNewFile", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("TS_FOLD_WORKAROUND", {}),
  callback = function()
    if vim.bo.filetype ~= "home-assistant" then
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr   = "nvim_treesitter#foldexpr()"
    end
  end
})
---ENDWORKAROUND
