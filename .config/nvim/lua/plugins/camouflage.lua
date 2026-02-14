-- camouflage.nvim (https://github.com/zeybek/camouflage.nvim)
--  Mask sensitive values in config files during screen sharing. Zero file modification - uses Neovim extmarks.

return {
  "zeybek/camouflage.nvim",
  event = "VeryLazy",
  opts = {
    auto_enable = true,
    reveal = { follow_cursor = true },
    pwned = { enabled = false },
    hooks = {
      on_before_decorate = function(bufnr)
        local disabled_filetypes = { "yaml.homeassistant", "gitconfig" }
        if vim.tbl_contains(disabled_filetypes, vim.bo[bufnr].filetype) then
          return false
        end

        -- Disable for JSON files unless they likely contain secrets
        if vim.bo[bufnr].filetype == "json" then
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
          local secret_patterns = { "credentials", "secrets", "tokens", "auth", "keyfile" }
          for _, pattern in ipairs(secret_patterns) do
            if filename:lower():find(pattern) then
              return true
            end
          end
          return false
        end

        return true
      end,
    },
  },
  keys = {
    { "[om", function() require("camouflage").enable() end, desc = "Enable camouflage (mask secrets)" },
    { "]om", function() require("camouflage").disable() end, desc = "Disable camouflage (reveal secrets)" },
    { "<leader>ucy", "<cmd>CamouflageYank<CR>", desc = "Yank concealed value" },
  },
}
