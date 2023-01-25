-- nvim-lint (https://github.com/mfussenegger/nvim-lint)
--  An asynchronous linter plugin for Neovim complementary to the built-in Language Server Protocol support.
--  We use this linter because vale is silently failing in null-ls

return {
  "mfussenegger/nvim-lint",
  ft = { "markdown" },
  init = function()
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      callback = function()
        require("lint").try_lint()
      end,
    })
  end,
  config = function()
    require("lint").linters_by_ft = {
      markdown = { "markdownlint", "vale" }
    }
  end
}
