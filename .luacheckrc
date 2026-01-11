-- .luacheckrc
-- Luacheck configuration for Neovim config validation

std = "luajit"

-- Allow these global variables (can be read and modified)
globals = {
  "vim",      -- Neovim global API (allows setting vim.opt, vim.g, etc.)
  "Snacks",   -- Snacks.nvim plugin global
  "Set_hl",   -- Custom global function from config/init.lua
}

-- Disable line length checks (handled by stylua)
max_line_length = false

-- Ignore unused arguments (code 212) - common in Neovim callback signatures
-- Don't ignore undefined variables (code 113) - these are real issues
ignore = {
  "212", -- unused argument
}

-- Files to exclude
exclude_files = {
  ".local/**",
  "**/.git/**",
}
