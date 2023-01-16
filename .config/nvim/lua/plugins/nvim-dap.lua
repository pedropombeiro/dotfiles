-- nvim-dap (https://github.com/mfussenegger/nvim-dap)
--  Debug Adapter Protocol client implementation for Neovim

return {
  "mfussenegger/nvim-dap",
  dependencies = {
    {
      "theHamsta/nvim-dap-virtual-text",
      dependencies = "nvim-treesitter/nvim-treesitter",
      config = true
    },
    "rcarriga/nvim-dap-ui",
  },
  config = function()
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

    vim.fn.sign_define('DapBreakpoint', { text = '🛑', texthl = '', linehl = '', numhl = '' })
  end
}
