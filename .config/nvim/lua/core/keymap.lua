--- key bindings -------------------------------------------------------------------

local m = require("mapx").setup { global = "force", whichkey = true }
local wk = require("which-key")

wk.register({
  ["<C-Q>"] = { "Quit all" },
  ["<C-S>"] = { "Save file" },
}, { mode = { "n", "i" } })
wk.register({
  ["<C-L>"] = { "Remove highlight" },
}, { mode = "n" })
wk.register({
  ["Y"] = { "Yank lines" },
}, { mode = "n" })

m.nname("z", "Folds")

-- Workaround: Fix <s-space> being rendered as 32;2u in LazyGit
-- https://neovim.discourse.group/t/shift-space-escape-sequence-in-term-introduced-between-in-neovim-0-6-and-0-7/2816
m.tnoremap("<s-space>", "<space>")

m.nnoremap("&", ":&&<CR>")
m.xnoremap("&", ":&&<CR>")

m.nname("<leader>t", "Tabs")
m.noremap("<leader>tn", ":tabnew<CR>", "Open new tab")
m.noremap("<leader>tc", ":tabclose<CR>", "Close tab")
m.noremap("<leader>tt", ":tabs<CR>", "List tabs")

m.nnoremap("<C-s>", ":w<CR>")
m.inoremap("<C-s>", "<Esc>:w<CR>")
m.nnoremap("<C-q>", ":qa<CR>")
m.inoremap("<C-q>", "<Esc>:qa<CR>")
-- Switch between recently edited buffers (Mastering Vim Quickly)
m.nnoremap("<C-b>", "<C-^>", "Switch to recent buffer")
m.inoremap("<C-b>", "<Esc><C-^>", "Switch to recent buffer")

-- Map Esc to normal mode in terminal mode
m.tnoremap("<Esc><Esc>", "<C-\\><C-n>")

-- make . work with visually selected lines
m.vnoremap(".", ":normal.<CR>")

-- Center next/previous matches on the screen (Mastering Vim Quickly)
m.nnoremap("n", "nzz", "Next match (centered)")
m.nnoremap("N", "Nzz", "Previous match (centered)")

---- Move lines with single key combo (Mastering Vim Quickly)
-- Insert mode
m.inoremap("<C-j>", "<Esc>:m .+1<CR>==gi", "Move line up")
m.inoremap("<C-k>", "<Esc>:m .-2<CR>==gi", "Move line down")

-- Visual mode
m.vnoremap("<C-j>", ":m '>+1<CR>gv=gv", "Move line up")
m.vnoremap("<C-k>", ":m '<-2<CR>gv=gv", "Move line down")

m.nnoremap("<leader>~", ":<C-U>setlocal lcs=tab:>-,trail:-,eol:$ list! list? <CR>", "Toggle special characters")

-- Map gp to select recently pasted text
-- (https://vim.fandom.com/wiki/Selecting_your_pasted_text)
m.nnoremap("gp", "'`[' . strpart(getregtype(), 0, 1) . '`]'", { expr = true }, "Select last pasted text")

-- ========================================
-- General vim sanity improvements
-- ========================================
--
--
m.nname("<leader>y", "Yank")

m.nnoremap("<leader>yy", ":let @*=expand('%')<CR>", "silent", "Yank file path")

-- alias yw to yank the entire word 'yank inner word'
-- even if the cursor is halfway inside the word
-- FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
m.nnoremap("<leader>yw", "yiww", "Yank whole inner word")

-- ,ow = 'overwrite word', replace a word with what's in the yank buffer
-- FIXME: will not properly repeat when you use a dot (tie into repeat.vim)
m.nnoremap("<leader>ow", '"_diwhp', "Overwrite whole word")

m.map("<leader>#", "ysiw#", "Surround word with #{}")
m.vmap("<leader>#", 'c#{<C-R>"}<Esc>', "Surround word with #{}")

m.map('<leader>"', 'ysiW"', "Surround word with quotes")
m.vmap('<leader>"', 'c"<C-R>""<Esc>', "Surround word with quotes")

m.map("<leader>'", "ysiW'", "Surround word with single quotes")
m.vmap("<leader>'", "c'<C-R>\"'<Esc>", "Surround word with single quotes")

m.map("<leader>`", "ysiW`", "Surround word with ticks")

-- <leader>) or <leader>( Surround a word with (parens)
-- The difference is in whether a space is put in
local symbols = { ["("] = ")", ["["] = "]", ["{"] = "}" }
for open_sym, close_sym in pairs(symbols) do
  local open_desc = "Surround word with " .. open_sym .. " " .. close_sym
  local close_desc = "Surround word with " .. open_sym .. close_sym

  m.map("<leader>" .. open_sym, "ysiw" .. open_sym, open_desc)
  m.map("<leader>" .. close_sym, "ysiw" .. close_sym, close_desc)
  m.vmap("<leader>(" .. open_sym, "c" .. open_sym .. '") <C-R>"' .. close_sym .. "<Esc>", open_desc)
  m.vmap("<leader>)", "c" .. open_sym .. '<C-R>"' .. close_sym .. "<Esc>", close_desc)
end

m.nmap("<leader>gr", ":Dispatch bundle exec rubocop --auto-correct %<CR>", { ft = "ruby" }, "Reformat file with Rubocop")

m.nnoremap("gv", "`[v`]", "Select last pasted text")

-- Window movement
m.nnoremap("<C-h>", "<cmd>wincmd h<CR>", "Move to window to left")
m.nnoremap("<C-j>", "<cmd>wincmd j<CR>", "Move to window below")
m.nnoremap("<C-k>", "<cmd>wincmd k<CR>", "Move to window above")
m.nnoremap("<C-l>", "<cmd>wincmd l<CR>", "Move to window to right")
m.nnoremap("<C-S-Up>", "<cmd>resize +2<CR>", "Resize window up")
m.tnoremap("<C-S-Up>", "<cmd>resize +2<CR>", "Resize window up")
m.nnoremap("<C-S-Left>", "<cmd>vertical resize +2<CR>", "Resize window left")
m.tnoremap("<C-S-Left>", "<cmd>vertical resize +2<CR>", "Resize window left")
m.nnoremap("<C-S-Right>", "<cmd>vertical resize -2<CR>", "Resize window right")
m.tnoremap("<C-S-Right>", "<cmd>vertical resize -2<CR>", "Resize window right")
m.nnoremap("<C-S-Down>", "<cmd>resize -2<CR>", "Resize window down")
m.tnoremap("<C-S-Down>", "<cmd>resize -2<CR>", "Resize window down")
