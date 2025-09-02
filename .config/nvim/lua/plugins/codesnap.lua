-- codesnap.nvim (https://github.com/mistricky/codesnap.nvim)
-- 📸 Snapshot plugin with rich features that can make pretty code snapshots for Neovim

---@module "lazy"
---@type LazySpec
return {
  "mistricky/codesnap.nvim",
  build = "make build_generator",
  event = { "BufNewFile", "BufReadPost" },
  cond = function() return vim.env.SSH_CONNECTION == nil end,
  keys = {
    { "<leader>.s", "<esc><cmd>CodeSnap<cr>", mode = "x", desc = "Save snaped code into clipboard" },
    { "<leader>.S", "<esc><cmd>CodeSnapSave<cr>", mode = "x", desc = "Save snaped code to ~/Desktop" },
  },
  opts = {
    mac_window_bar = false,
    code_font_family = "JetBrains Mono",
    watermark = "@pedropombeiro",
    watermark_font_family = "Helvetica",
    bg_theme = "default",
    breadcrumbs_separator = "/",
    has_breadcrumbs = true,
    has_line_number = true,
    show_workspace = true,
    bg_x_padding = 0,
    bg_y_padding = 0,
    save_path = os.getenv("HOME") .. "/Desktop",
  },
}
