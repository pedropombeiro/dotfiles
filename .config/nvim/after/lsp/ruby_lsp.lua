return {
  mason = false,
  cmd = { vim.fn.expand("~/.local/share/mise/shims/ruby-lsp") },
  init_options = {
    -- https://shopify.github.io/ruby-lsp/editors.html#all-initialization-options
    formatter = "standard",
    linters = { "standard" },
  },
}
