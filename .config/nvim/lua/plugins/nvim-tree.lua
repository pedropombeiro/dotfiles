-- nvim-tree.lua (https://github.com/nvim-tree/nvim-tree.lua/)
--  A file explorer tree for neovim written in lua

require("nvim-tree").setup({
  disable_netrw = false,
  hijack_netrw = true,
  reload_on_bufenter = true,
  sort_by = "case_sensitive",
  view = {
    adaptive_size = true,
    side = "right",
  },
  renderer = {
    group_empty = true,
    highlight_git = true,
    highlight_opened_files = "icon",
  },
  filters = {
    dotfiles = false,
    custom = { "^.DS_Store$", "^.git$", ".zwc$" },
  },
  actions = {
    expand_all = {
      exclude = { ".git" },
    },
    open_file = {
      quit_on_open = true,
    },
  },
  update_focused_file = {
    enable = true,
    update_cwd = false,
  },
})

local map = vim.keymap.set

map({ "n", "v" }, "<C-\\>", "<Cmd>NvimTreeFindFileToggle<CR>")

-- Restore URL handling from disabled netrw plugin
if vim.fn.has("mac") == 1 then
  map("n", "gx", '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>')
elseif vim.fn.has("unix") == 1 then
  map("n", "gx", '<Cmd>call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>')
else
  map("n", "gx", "<Cmd>lua print(\"Error: gx is not supported on this OS!\")<CR>")
end
