-- nvim-dap-ui (https://github.com/rcarriga/nvim-dap-ui)
--  A UI for nvim-dap

require("dapui").setup()

local opts = { silent = true, noremap = true }
vim.keymap.set("v", "<leader>de", require("dapui").eval, opts)
vim.keymap.set("n", "<leader>dui", require('dapui').toggle, opts)
vim.keymap.set("n", "<leader>dro", function() require('dap').repl.open() end, opts)
