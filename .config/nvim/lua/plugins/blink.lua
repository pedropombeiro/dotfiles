-- blink.nvim (https://github.com/saghen/blink.cmp)
--  Performant, batteries-included completion plugin for Neovim.

return {
  -- auto completion
  {
    'saghen/blink.cmp',
    -- optional: provides snippets for the snippet source
    dependencies = {
      'rafamadriz/friendly-snippets',
    },

    -- use a release tag to download pre-built binaries
    version = '*',

    event = 'InsertEnter',

    cond = function()
      if vim.fn.has('unix') == 1 then -- Check if it's a Unix-like system (Linux, macOS, etc.)
        local uname_output = vim.fn.system('uname -a')
        if uname_output then
          return not string.find(string.lower(uname_output), 'qnap')
        end
      end

      return true
    end,
    ---@module 'blink.cmp'
    ---@diagnostic disable-next-line: undefined-doc-name
    ---@type blink.cmp.Config
    opts = {
      -- 'default' for mappings similar to built-in completion
      -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
      -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
      -- See the full "keymap" documentation for information on defining your own keymap.
      keymap = { preset = 'super-tab' },

      appearance = {
        -- Sets the fallback highlight groups to nvim-cmp's highlight groups
        -- Useful for when your theme doesn't support blink.cmp
        -- Will be removed in a future release
        use_nvim_cmp_as_default = true,
        -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        accept = {
          -- experimental auto-brackets support
          auto_brackets = {
            enabled = true,
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 500,
        },
        ghost_text = { enabled = true },
        menu = {
          draw = {
            treesitter = { 'lsp' },
          },
        },
      },

      signature = { enabled = true },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
    },
    opts_extend = { 'sources.default' },
  },
}
