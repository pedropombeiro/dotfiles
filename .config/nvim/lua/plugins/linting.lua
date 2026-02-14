-- nvim-lint (https://github.com/mfussenegger/nvim-lint)
--  An asynchronous linter plugin for Neovim complementary to the built-in Language Server Protocol support.

return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    -- stylua: ignore
    linters_by_ft = {
      dockerfile             = { "hadolint" },
      eruby                  = { "erb_lint" },
      gitcommit              = { "gitlint" },
      go                     = { "golangcilint" },
      json                   = { "jsonlint" },
      make                   = { "checkmake" },
      markdown               = { "vale" },
      python                 = { "mypy" },
      sh                     = { "shellcheck" },
      text                   = { "vale" },
      yaml                   = { "yamllint", "actionlint" },
      ["yaml.homeassistant"] = { "yamllint" },
      zsh                    = { "zsh" },
    },
  },
  config = function(_, opts)
    local lint = require("lint")
    lint.linters_by_ft = opts.linters_by_ft

    -- Lint on save, insert leave, and after reading a file
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
      callback = function()
        -- Only lint if the buffer has a name (skip scratch buffers)
        if vim.api.nvim_buf_get_name(0) ~= "" then
          lint.try_lint()
        end
      end,
    })
  end,
}
