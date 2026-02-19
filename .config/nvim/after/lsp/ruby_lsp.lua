return {
  mason = false,
  cmd = { vim.fn.expand("~/.local/share/mise/shims/ruby-lsp") },
  -- Override upstream reuse_client which has a bug: on the first buffer there
  -- are no existing clients, so reuse_client never runs and cmd_cwd is never
  -- set on client 1's config.  The second buffer then compares nil vs root_dir
  -- and creates a duplicate.  Compare root_dir directly instead.
  reuse_client = function(client, config)
    return client.name == config.name and client.config.root_dir == config.root_dir
  end,
  init_options = {
    -- https://shopify.github.io/ruby-lsp/editors.html#all-initialization-options
    formatter = "standard",
    linters = { "standard" },
  },
}
