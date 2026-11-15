-- Local Yatline adapter. Syntax/file colors come from the upstream Yazi theme.
return {
  setup = function()
    return {
      style_a = {
        fg = "#16161e",
        bg_mode = { normal = "#7aa2f7", select = "#bb9af7", un_set = "#ff9e64" },
      },
      style_b = { bg = "#3b4261", fg = "#c0caf5" },
      style_c = { bg = "#292e42", fg = "#a9b1d6" },
      permissions_t_fg = "#7aa2f7",
      permissions_r_fg = "#e0af68",
      permissions_w_fg = "#f7768e",
      permissions_x_fg = "#9ece6a",
      permissions_s_fg = "#565f89",
      selected = { icon = "󰻭", fg = "#e0af68" },
      copied = { icon = "", fg = "#9ece6a" },
      cut = { icon = "", fg = "#f7768e" },
      files = { icon = "", fg = "#7aa2f7" },
      filtereds = { icon = "", fg = "#bb9af7" },
      total = { icon = "󰮍", fg = "#e0af68" },
      success = { icon = "", fg = "#9ece6a" },
      failed = { icon = "", fg = "#f7768e" },
      branch_color = "#c0caf5",
      remote_branch_color = "#bb9af7",
      tag_color = "#7dcfff",
      commit_color = "#bb9af7",
      behind_color = "#ff9e64",
      ahead_color = "#9ece6a",
      behind_remote_color = "#ff9e64",
      ahead_remote_color = "#9ece6a",
      stashes_color = "#bb9af7",
      state_color = "#f7768e",
      staged_color = "#9ece6a",
      unstaged_color = "#ff9e64",
      untracked_color = "#7dcfff",
    }
  end,
}
