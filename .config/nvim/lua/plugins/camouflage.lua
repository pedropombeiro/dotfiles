-- camouflage.nvim (https://github.com/zeybek/camouflage.nvim)
--  Mask sensitive values in config files during screen sharing. Zero file modification - uses Neovim extmarks.

local disabled_filetypes = { "yaml.homeassistant", "gitconfig" }
local selective_filetypes = { yaml = true, toml = true }

local sensitive_keys = {
  "password", "passwd", "secret", "token", "api_key", "apikey",
  "private_key", "credentials", "auth", "bearer", "access_key",
  "client_secret", "database_url", "connection_string", "encryption_key",
}

local json_secret_filenames = { "credentials", "secrets", "tokens", "auth", "keyfile" }

local function matches_any(str, patterns)
  for _, pattern in ipairs(patterns) do
    if str:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

local function should_decorate(bufnr)
  local ft = vim.bo[bufnr].filetype
  if vim.tbl_contains(disabled_filetypes, ft) then
    return false
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath:find("%.github/workflows/") then
    return false
  end

  if ft == "json" then
    local filename = vim.fn.fnamemodify(filepath, ":t"):lower()
    return matches_any(filename, json_secret_filenames)
  end

  return true
end

local function should_mask_variable(bufnr, var)
  if not selective_filetypes[vim.bo[bufnr].filetype] then
    return true
  end
  return matches_any(var.key:lower(), sensitive_keys)
end

return {
  "zeybek/camouflage.nvim",
  event = "VeryLazy",
  opts = {
    auto_enable = true,
    reveal = { follow_cursor = true },
    pwned = { enabled = false },
    hooks = {
      on_before_decorate = should_decorate,
      on_variable_detected = should_mask_variable,
    },
  },
  keys = {
    { "[om", function() require("camouflage").enable() end, desc = "Enable camouflage (mask secrets)" },
    { "]om", function() require("camouflage").disable() end, desc = "Disable camouflage (reveal secrets)" },
    { "<leader>ucy", "<cmd>CamouflageYank<CR>", desc = "Yank concealed value" },
  },
}
