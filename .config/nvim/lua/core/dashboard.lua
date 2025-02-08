vim.api.nvim_create_user_command("Dashboard", function() Snacks.dashboard.open() end, { desc = "Open dashboard" })
