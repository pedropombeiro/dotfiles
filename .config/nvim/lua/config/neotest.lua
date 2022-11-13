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
})


local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<leader>rt", neotest.run.run, opts)
vim.keymap.set("n", "<leader>rT", function() neotest.run.run(vim.fn.expand("%")) end, opts)
vim.keymap.set("n", "<leader>rr", neotest.summary.open, opts)

--  function! TestBranch()
--    Dispatch bin/rspec $(git diff --name-only --diff-filter=AM master | grep 'spec/')
--  endfunction
--  nnoremap <leader>rb :call TestBranch()<CR>
