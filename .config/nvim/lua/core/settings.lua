--- General config ------------------------------------------------------------------

local opt = vim.opt

---@format disable
opt.shortmess:append({ W = true, I = true, c = true })
opt.smartindent = true
opt.swapfile    = false -- disable the swapfile
opt.history     = 2000
opt.updatetime  = 1000
opt.completeopt = "menu,menuone,noselect,preview"
opt.wildmenu    = true  -- set zsh-alike autocomplete behavior
opt.wildmode    = "longest:full,full"
opt.winminwidth = 5     -- Minimum window width
opt.wrap        = false -- Disable line wrap
opt.expandtab   = true
opt.tabpagemax  = 40    -- Max number of tab pages that can be opened from the command line
opt.errorbells  = false
opt.confirm     = true  -- Display a confirmation dialog when closing a dirty buffer (Mastering Vim Quickly)

vim.g.loaded_node_provider    = 0     -- disable Node.js provider
vim.g.loaded_perl_provider    = 0     -- disable Perl support
vim.g.loaded_python3_provider = 0     -- disable python3 provider, we don't need python plugins
vim.g.loaded_ruby_provider    = 0     -- disable Ruby provider

-- This makes vim act like all other editors, buffers can
-- exist in the background without being in a window.
-- http://items.sjbach.com/319/configuring-vim-right
opt.hidden     = true

-- Make macros render faster (lazy draw)
opt.lazyredraw = true

---------------- Persistent Undo ------------------
opt.undofile                  = true
local vimrc_undofile_augroup = vim.api.nvim_create_augroup("vimrc_undofile", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "/tmp/*",
  group = vimrc_undofile_augroup,
  command = "setlocal noundofile",
})

---------------- Spelling ------------------
opt.spelllang = "en_us"
opt.spell     = false

-- netrw customization (https://shapeshed.com/vim-netrw/)
vim.g.netrw_liststyle    = 1 -- wide view
vim.g.netrw_browse_split = 3
vim.g.netrw_altv         = 1
vim.g.netrw_winsize      = 25

---------------- Security --------------------------
opt.modelines = 0
opt.modeline  = false

-- Q: Mouse reporting in vim doesn't work for some rows/columns in a big terminal window.
if vim.fn.has("mouse_sgr") ~= 0 then
  vim.cmd("set ttymouse=sgr")
end

---------------- Layout --------------------------

opt.title          = false -- change terms title
opt.number         = true  -- show line numbers
opt.ruler          = true  -- show ruler in status line
opt.laststatus     = 0     -- never show status line
opt.scrolloff      = 4     -- keep 4 lines off the edges
opt.pumheight      = 10    -- popup menu height
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
opt.signcolumn     = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
opt.splitbelow     = true  -- Put new windows below current
opt.splitright     = true  -- Put new windows right of current

-- enable a second-stage diff on individual hunks to provide much more accurate diffs.
opt.diffopt:append("linematch:60")

vim.fn.setenv("GIT_CONFIG_PARAMETERS", "'delta.side-by-side=false'") -- Disable .gitconfig"s delta option

opt.relativenumber = true

---------------- Search --------------------------

opt.incsearch  = true -- Find the next match as we type the search
opt.hlsearch   = true -- Highlight searches by default
opt.ignorecase = true -- Ignore case when searching...
opt.smartcase  = true -- ...unless we type a capital
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg    = "rg --vimgrep --smart-case --follow "

---------------- Format --------------------------

opt.encoding     = "utf-8"
opt.fileformats  = "unix,dos,mac" -- supported formats
opt.bomb         = false          -- don"t use a BOM
opt.shiftwidth   = 2
opt.softtabstop  = 2
opt.tabstop      = 2

opt.list         = true
opt.listchars    = {
  precedes = "⟨",
  extends  = "⟩",
  trail    = "·",
  tab      = "│·",
  nbsp     = "␣"
}
---@format enable

local term_helper_augroup = vim.api.nvim_create_augroup("term_helper", { clear = true })
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  group = term_helper_augroup,
  command = "match none | setlocal nonumber norelativenumber", -- clear the highlighting and line numbers if we"re a terminal buffer
})
