-- mason-tool-installer.nvim (https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim)
--  Install and upgrade third party tools automatically.
--  Replaces mason-null-ls.nvim's ensure_installed functionality with a dedicated
--  tool installer that runs on startup and handles concurrent installs correctly.

local function has_cargo()
  return vim.fn.executable("cargo") == 1
end

local function has_go()
  return vim.fn.executable("go") == 1
end

local function has_ruby()
  local p = vim.fn.exepath("ruby")
  return p ~= "" and not p:find("/usr/bin/ruby")
end

-- QTS ships an old glibc, so some prebuilt binaries install but fail to run
local function runs_on_platform()
  return vim.g.distro ~= "qts"
end

-- Tools not needed for the NAS role
local function needed_for_role()
  return vim.g.yadm_class ~= "NAS"
end

return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = {
    "mason-org/mason.nvim",
  },
  opts = {
    ensure_installed = {
      "actionlint",
      "bash-language-server",
      { "checkmake", condition = runs_on_platform },
      "docker-compose-language-service",
      "dockerfile-language-server",
      { "erb-formatter", condition = has_ruby },
      { "erb-lint", condition = has_ruby },
      "fixjson",
      "gitlint",
      "hadolint",
      { "gitlab-ci-ls", condition = has_cargo },
      { "golangci-lint", condition = has_go },
      { "golangci-lint-langserver", condition = has_go },
      { "goimports", condition = has_go },
      { "gofumpt", condition = has_go },
      { "gopls", condition = has_go },
      "jsonlint",
      "json-lsp",
      "lua_ls",
      "markdownlint-cli2",
      { "mypy", condition = needed_for_role },
      "prettier",
      { "pyrefly", condition = needed_for_role },
      { "ruby-lsp", condition = has_ruby },
      "shfmt",
      "shellcheck",
      { "stylua", condition = runs_on_platform },
      "taplo",
      { "tree-sitter-cli", condition = runs_on_platform },
      { "vale", condition = runs_on_platform },
      "vtsls",
      "yamlfmt",
      "yaml-language-server",
      "yamllint",
    },
  },
}
