-- nvim-dap (https://github.com/mfussenegger/nvim-dap)
--  Debug Adapter Protocol client implementation for Neovim

return {
  "mfussenegger/nvim-dap",
  cmd = { "BreakpointToggle", "Debug", "DapREPL" },
  dependencies = {
    {
      "theHamsta/nvim-dap-virtual-text",
      dependencies = "nvim-treesitter/nvim-treesitter",
      config = true
    },
    {
      "rcarriga/nvim-dap-ui", --  A UI for nvim-dap
      config = function()
        require("dapui").setup()
      end,
    }
  },
  init = function()
    local m = require("mapx")
    local silent = { silent = true }

    m.nnoremap("<S-F5>", function() require("dap").close() end, "Close DAP")
    m.nnoremap("<F5>", function() require("dap").continue() end, "Continue execution")
    m.nnoremap("<F7>", function() require("dap").step_into() end, "Step into")
    m.nnoremap("<F8>", function() require("dap").step_over() end, "Step over")
    m.nnoremap("<F9>", function() require("dap").toggle_breakpoint() end, "Toggle breakpoint")
    m.nname("<leader>d", "Debug")
    m.nnoremap("<leader>dl", function() require("dap-go").debug_last_test() end, { ft = "go" }, "Debug last Go test")
    m.nnoremap("<leader>dt", function() require("dap-go").debug_test() end, { ft = "go" }, "Debug Go test")
    m.nnoremap("<leader>rl", function() require("dap-go").run_last() end, { ft = "go" }, "Run last Go test")

    -- DAP UI
    m.vnoremap("<leader>de", function() require("dapui").eval() end, silent, "Evaluate with DAP")
    m.nnoremap("<leader>dui", function() require("dapui").toggle() end, silent, "Toggle DAP UI")
    m.nnoremap("<leader>dro", function() require("dap").repl.open() end, silent, "Open REPL")
  end,
  config = function()
    local dap = require("dap")

    -- Needs bash-debug-adapter installed (:MasonInstall bash-language-server)
    dap.adapters.bashdb = {
      type = "executable";
      command = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/bash-debug-adapter";
      name = "bashdb";
    }

    local sh_config = {
      {
        type = "bashdb";
        request = "launch";
        name = "Launch file";
        showDebugOutput = false;
        pathBashdb = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir/bashdb";
        pathBashdbLib = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir";
        trace = true;
        file = "${file}";
        program = "${file}";
        cwd = "${workspaceFolder}";
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
        type = "python";
        request = "launch";
        name = "Launch file";
        program = "${file}";
        pythonPath = function()
          return vim.fn.system("which python"):gsub("\n[^\n]*$", "");
        end;
      },
    }

    vim.fn.sign_define("DapBreakpoint", { text = "🛑", texthl = "", linehl = "", numhl = "" })
  end
}
