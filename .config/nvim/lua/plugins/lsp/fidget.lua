-- fidget.nvim (https://github.com/j-hui/fidget.nvim)
--   Standalone UI for nvim-lsp progress

return {
  'j-hui/fidget.nvim',
  tag = 'legacy',
  event = 'LspAttach',
  opts = {
    text = {
      spinner = 'dots_snake'
    },
    sources = {                -- Sources to configure
      ['null-ls'] = {          -- Name of source
        ignore = true,         -- Ignore notifications from this source
      },
    },
  }
}
