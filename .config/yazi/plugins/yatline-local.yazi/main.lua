-- Shared local layout; upstream Yazi themes supply syntax and file colors.
return {
  setup = function()
    local root = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/dotfiles"
    local c = dofile(root .. "/yatline.lua")
    return {
      style_a = { fg = c.background, bg_mode = { normal = c.normal, select = c.select, un_set = c.waiting } },
      style_b = { bg = c.border, fg = c.text },
      style_c = { bg = c.surface, fg = c.foreground },
      permissions_t_fg = c.normal,
      permissions_r_fg = c.yellow,
      permissions_w_fg = c.red,
      permissions_x_fg = c.green,
      permissions_s_fg = c.muted,
      selected = { icon = "󰻭", fg = c.yellow },
      copied = { icon = "", fg = c.green },
      cut = { icon = "", fg = c.red },
      files = { icon = "", fg = c.normal },
      filtereds = { icon = "", fg = c.select },
      total = { icon = "󰮍", fg = c.yellow },
      success = { icon = "", fg = c.green },
      failed = { icon = "", fg = c.red },
      branch_color = c.text,
      remote_branch_color = c.remote,
      tag_color = c.cyan,
      commit_color = c.commit,
      behind_color = c.waiting,
      ahead_color = c.green,
      behind_remote_color = c.waiting,
      ahead_remote_color = c.green,
      stashes_color = c.stashes,
      state_color = c.red,
      staged_color = c.green,
      unstaged_color = c.waiting,
      untracked_color = c.cyan,
    }
  end,
}
