-- Neotest (https://github.com/nvim-neotest/neotest)
--  An extensible framework for interacting with tests within NeoVim.

-- get neotest namespace (api call creates or returns namespace)
local neotest_ns = vim.api.nvim_create_namespace("neotest")
vim.diagnostic.config({
  virtual_text = {
    format = function(diagnostic)
      local message = diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
      return message
    end,
  },
}, neotest_ns)

local neotest = require("neotest")
neotest.setup({
  adapters = {
    require("neotest-go") {
      experimental = {
        test_table = true,
      },
      args = { "-count=1", "-timeout=60s" }
    },
    require("neotest-rspec")({
      rspec_cmd = function()
        return vim.tbl_flatten({
          "bundle",
          "exec",
          "rspec",
        })
      end
    }),
  },
  icons = {
    expanded = "",
    child_prefix = "",
    child_indent = "",
    final_child_prefix = "",
    non_collapsible = "",
    collapsed = "",

    passed = "",
    running = "",
    failed = "",
    unknown = ""
  },
})

-- Theming (from https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/config/init.lua)
local function define_highlights()
  vim.cmd([[
  hi default NeotestPassed ctermfg=Green guifg=#b8bb26
  hi default NeotestFailed ctermfg=Red guifg=#fb4934
  hi default NeotestRunning ctermfg=Yellow guifg=#fabd2f
  hi default NeotestSkipped ctermfg=Cyan guifg=#83a598
  hi default link NeotestTest Normal
  hi default NeotestNamespace ctermfg=Magenta guifg=#d3869b
  hi default NeotestFocused gui=bold,underline cterm=bold,underline
  hi default NeotestFile ctermfg=Cyan guifg=#83a598
  hi default NeotestDir ctermfg=Cyan guifg=#83a598
  hi default NeotestIndent ctermfg=Grey guifg=#a89984
  hi default NeotestExpandMarker ctermfg=Grey guifg=#bdae93
  hi default NeotestAdapterName ctermfg=Red guifg=#cc241d
  hi default NeotestWinSelect ctermfg=Cyan guifg=#83a598 gui=bold
  hi default NeotestMarked ctermfg=Brown guifg=#fe8019 gui=bold
  hi default NeotestTarget ctermfg=Red guifg=#cc241d
  hi default link NeotestUnknown Normal
  ]])
end

--- Override Neotest default theme
local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/theme.sh
if theme == "gruvbox" then
  local augroup = vim.api.nvim_create_augroup("NeotestColorSchemeRefresh", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { callback = define_highlights, group = augroup })
  define_highlights()
end

-- Keymaps
local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<leader>rt", neotest.run.run, opts)
vim.keymap.set("n", "<leader>rT", function() neotest.run.run(vim.fn.expand("%")) end, opts)
vim.keymap.set("n", "<leader>rr", neotest.summary.open, opts)

--  function! TestBranch()
--    Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')
--  endfunction
--  nnoremap <leader>rb :call TestBranch()<CR>
