-- auto-session (https://github.com/rmagatti/auto-session)
--  A small automated session manager for Neovim

return {
  "rmagatti/auto-session",
  config = function()
    vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

    require("auto-session").setup {
      log_level = "error",
      auto_restore_enabled = false,
      auto_session_enable_last_session = false,
      auto_session_suppress_dirs = { "~/", "~/src", "~/Downloads", "/", "/share/Container" },

      cwd_change_handling = {
        post_cwd_changed_hook = function() -- example refreshing the lualine status line _after_ the cwd changes
          require("lualine").refresh() -- refresh lualine so the new session name is displayed in the status bar
        end,
      },
    }
  end
}
