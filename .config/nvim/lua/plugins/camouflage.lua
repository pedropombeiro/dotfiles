-- camouflage.nvim (https://github.com/zeybek/camouflage.nvim)
-- Mask sensitive values in config files during screen sharing.
-- Supports .env, JSON, YAML, TOML, XML, Terraform/HCL, Dockerfile, and more.
-- Zero file modification - uses Neovim extmarks.

return {
  "zeybek/camouflage.nvim",
  event = "VeryLazy",
  opts = {
    auto_enable = true,
    reveal = { follow_cursor = true },
    pwned = { enabled = false },
    hooks = {
      on_before_decorate = function(bufnr)
        return vim.bo[bufnr].filetype ~= "yaml.homeassistant"
      end,
    },
  },
  keys = {
    { "[om", function() require("camouflage").enable() end, desc = "Enable camouflage (mask secrets)" },
    { "]om", function() require("camouflage").disable() end, desc = "Disable camouflage (reveal secrets)" },
    { "<leader>ucy", "<cmd>CamouflageYank<CR>", desc = "Yank concealed value" },
  },
}
