--- General config ------------------------------------------------------------------

vim.opt.shortmess:append("I")
vim.opt.smartindent           = true
vim.opt.swapfile              = false -- disable the swapfile
vim.opt.history               = 2000
vim.opt.updatetime            = 1000
vim.opt.wildmenu              = true -- set zsh-alike autocomplete behavior
vim.opt.wildmode              = "full"
vim.opt.expandtab             = true
vim.opt.tabpagemax            = 40   -- Max number of tab pages that can be opened from the command line
vim.opt.errorbells            = false
vim.opt.confirm               = true -- Display a confirmation dialog when closing a dirty buffer (Mastering Vim Quickly)

vim.g.loaded_perl_provider    = 0    -- disable Perl support
vim.g.loaded_python3_provider = 0    -- disable python3 provider, we don't need python plugins

-- This makes vim act like all other editors, buffers can
-- exist in the background without being in a window.
-- http://items.sjbach.com/319/configuring-vim-right
vim.opt.hidden                = true

-- Make macros render faster (lazy draw)
vim.opt.lazyredraw            = true

---------------- Persistent Undo ------------------
vim.opt.undofile              = true
local vimrc_undofile_augroup  = vim.api.nvim_create_augroup("vimrc_undofile", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "/tmp/*",
  group = vimrc_undofile_augroup,
  command = "setlocal noundofile"
})

---------------- Spelling ------------------
vim.opt.spelllang        = "en_us"
vim.opt.spell            = false

-- netrw customization (https://shapeshed.com/vim-netrw/)
vim.g.netrw_liststyle    = 1 -- wide view
vim.g.netrw_browse_split = 3
vim.g.netrw_altv         = 1
vim.g.netrw_winsize      = 25

---------------- Security --------------------------
vim.opt.modelines        = 0
vim.opt.modeline         = false

-- Q: Mouse reporting in vim doesn't work for some rows/columns in a big terminal window.
if vim.fn.has("mouse_sgr") ~= 0 then
  vim.cmd("set ttymouse=sgr")
end

---------------- Layout --------------------------

vim.opt.title          = false -- change terms title
vim.opt.number         = true  -- show line numbers
vim.opt.ruler          = true  -- show ruler in status line
vim.opt.showmode       = true  -- always show mode
vim.opt.laststatus     = 2     -- always show status line
vim.opt.showcmd        = true  -- show the command being typed
vim.opt.scrolloff      = 4     -- keep 4 lines off the edges
vim.opt.pumheight      = 10    -- popup menu height

vim.opt.foldlevelstart = 99

vim.fn.setenv("GIT_CONFIG_PARAMETERS", "'delta.side-by-side=false'") -- Disable .gitconfig's delta option

-- Relative line number (Mastering Vim Quickly)
vim.opt.relativenumber = true
local toggle_relative_number_augroup = vim.api.nvim_create_augroup("toggle_relative_number", { clear = true })
vim.api.nvim_create_autocmd("InsertEnter", {
  pattern = "*",
  group = toggle_relative_number_augroup,
  command = "setlocal norelativenumber"
})
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  group = toggle_relative_number_augroup,
  command = "setlocal relativenumber"
})

---------------- Search --------------------------

vim.opt.incsearch    = true -- Find the next match as we type the search
vim.opt.hlsearch     = true -- Highlight searches by default
vim.opt.ignorecase   = true -- Ignore case when searching...
vim.opt.smartcase    = true -- ...unless we type a capital
vim.opt.grepprg      = "rg --vimgrep --smart-case --follow"

---------------- Format --------------------------

vim.opt.encoding     = "utf-8"
vim.opt.termencoding = "utf-8"
vim.opt.fileformats  = "unix,dos,mac" -- supported formats
vim.opt.bomb         = false          -- don't use a BOM
vim.opt.shiftwidth   = 2
vim.opt.softtabstop  = 2
vim.opt.tabstop      = 2

vim.opt.listchars    = {
  precedes = "⟨",
  extends = "⟩",
  eol = "↵",
  trail = "·",
  tab = "│·",
  nbsp = "␣"
}
vim.opt.list         = true

-- highlight trailing whitespace (Mastering Vim Quickly)
vim.cmd([[
  function! HighlightExtraWhitespace()
    highlight ExtraWhitespace ctermbg=red guibg=red
    match ExtraWhitespace /\s\+$/
  endfunction

  augroup TrailingSpace
    au!
    autocmd BufNewFile,BufRead * call HighlightExtraWhitespace()
    autocmd FileType alpha,help,neo-tree highlight clear ExtraWhitespace
  augroup END
]])

local save_fmt_augroup = vim.api.nvim_create_augroup("save_fmt", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  group = save_fmt_augroup,
  command = ":%s/\\s\\+$//e" -- remove trailing whitespace on save (Mastering Vim Quickly)
})

local term_helper_augroup = vim.api.nvim_create_augroup("term_helper", { clear = true })
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  group = term_helper_augroup,
  command = "match none" -- clear the highlighting if we're a terminal buffer
})

local justfile_open_augroup = vim.api.nvim_create_augroup("justfile_open", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  group = justfile_open_augroup,
  callback = function()
    if vim.api.nvim_get_option('makeprg') == 'make' then
      local justfile = vim.fn.findfile('.justfile', vim.fn.expand('%:p') .. ';')
      if #justfile > 0 then
        vim.opt_local.makeprg = 'just'
      end
    end
  end
})
