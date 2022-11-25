-- mason-null-ls.nvim (https://github.com/jayp0521/mason-null-ls.nvim)
--  mason-null-ls bridges mason.nvim with the null-ls plugin - making it easier to use both plugins together.
--  mason-null-ls.nvim closes some gaps that exist between mason.nvim and null-ls. Its main responsibilities are:
--    - provide extra convenience APIs such as the :NullLsInstall command
--    - allow you to (i) automatically install, and (ii) automatically set up a predefined list of sources
--    - translate between null-ls source names and mason.nvim package names (e.g. haml_lint <-> haml-lint)
--  **Note: this plugin uses the null-ls source names in the APIs it exposes - not mason.nvim package names.

require("mason-null-ls").setup({
  automatic_installation = false,
  ensure_installed = {
    "editorconfig-checker",
    "goimports",
    "hadolint",
    "jq",
    "markdownlint",
    "rubocop",
    "shellcheck",
    "shfmt",
    "stylua",
    "vale",
    "vint",
    "yamlfmt",
    "yamllint",
  },
})
