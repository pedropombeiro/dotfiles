-- Read persisted settings rather than potentially stale shell exports.
local root = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/dotfiles"
local name = vim.trim(table.concat(vim.fn.readfile(root .. "/theme"), "\n"))
assert(name:match("^[a-z0-9][a-z0-9%-]*$"), "Invalid dotfiles theme identifier")
local profile = vim.json.decode(table.concat(vim.fn.readfile(root .. "/themes/" .. name .. ".json"), "\n"))
profile.name = profile.nvim
return profile
