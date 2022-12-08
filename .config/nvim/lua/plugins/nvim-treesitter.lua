-- nvim-treesitter.vim (https://github.com/nvim-treesitter/nvim-treesitter)
--  Nvim Treesitter configurations and abstraction layer
--  The goal of nvim-treesitter is both to provide a simple and easy way to use the interface for tree-sitter in Neovim
--    and to provide some basic functionality such as highlighting based on it:

require "nvim-treesitter.configs".setup {
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
  },

  endwise = {
    enable = true,
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
    vim.opt.foldmethod = "expr"
    vim.opt.foldexpr   = "nvim_treesitter#foldexpr()"
  end
})
---ENDWORKAROUND
