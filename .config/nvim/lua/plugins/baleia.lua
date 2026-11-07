-- baleia.nvim (https://github.com/m00qek/baleia.nvim)
--   Colorize text with ANSI escape sequences (8, 16, 256 or TrueColor)

return {
  "m00qek/baleia.nvim",
  version = "*",
  -- Release tags carry test-only submodules that `main` dropped, so
  -- checking out a tag with `--recurse-submodules` fails
  submodules = false,
  cmd = { "BaleiaColorize", "BaleiaLogs" },
  config = function()
    vim.g.baleia = require("baleia").setup({})

    -- Colorize the current buffer once and strip the escape codes
    vim.api.nvim_create_user_command("BaleiaColorize", function()
      vim.g.baleia.once(vim.api.nvim_get_current_buf())
    end, { bang = true, desc = "Colorize ANSI escape codes in buffer" })

    vim.api.nvim_create_user_command("BaleiaLogs", vim.cmd.messages, { bang = true, desc = "Show Baleia logs" })
  end,
}
