-- nvim-dap (https://github.com/mfussenegger/nvim-dap)
--  Debug Adapter Protocol client implementation for Neovim

local dap = require('dap')

-- Needs bash-debug-adapter installed (:MasonInstall bash-language-server)
dap.adapters.bashdb = {
  type = 'executable';
  command = vim.fn.stdpath("data") .. '/mason/packages/bash-debug-adapter/bash-debug-adapter';
  name = 'bashdb';
}

local sh_config = {
  {
    type = 'bashdb';
    request = 'launch';
    name = "Launch file";
    showDebugOutput = false;
    pathBashdb = vim.fn.stdpath("data") .. '/mason/packages/bash-debug-adapter/extension/bashdb_dir/bashdb';
    pathBashdbLib = vim.fn.stdpath("data") .. '/mason/packages/bash-debug-adapter/extension/bashdb_dir';
    trace = true;
    file = "${file}";
    program = "${file}";
    cwd = '${workspaceFolder}';
    pathCat = "cat";
    pathBash = vim.fn.system("which bash"):gsub("\n[^\n]*$", "");
    pathMkfifo = "mkfifo";
    pathPkill = "pkill";
    args = {};
    env = {};
    terminalKind = "integrated";
  }
}

dap.configurations.sh = sh_config
dap.configurations.zsh = sh_config

-- Needs debug-py installed (:MasonInstall debug-py)
dap.configurations.python = {
  {
    type = 'python';
    request = 'launch';
    name = "Launch file";
    program = "${file}";
    pythonPath = function()
      return vim.fn.system("which python"):gsub("\n[^\n]*$", "");
    end;
  },
}

vim.keymap.set("n", "<S-F5>", dap.close)
vim.keymap.set("n", "<F5>", dap.continue)
vim.keymap.set("n", "<F7>", dap.step_into)
vim.keymap.set("n", "<F8>", dap.step_over)
vim.keymap.set("n", "<F9>", dap.toggle_breakpoint)
vim.keymap.set("n", "<leader>dl", function() require("dap-go").debug_last_test() end)
vim.keymap.set("n", "<leader>dt", function() require("dap-go").debug_test() end)
vim.keymap.set("n", "<leader>rl", dap.run_last)

vim.fn.sign_define('DapBreakpoint', { text = '🛑', texthl = '', linehl = '', numhl = '' })
