-- nvim-dap (https://github.com/mfussenegger/nvim-dap)
--  Debug Adapter Protocol client implementation for Neovim

return {
  {
    --- An extension for nvim-dap providing configurations for launching go debugger (delve)
    --- and debugging individual tests
    'leoluz/nvim-dap-go',
    keys = {
      { '<leader>dl', function() require('dap-go').debug_last_test() end, desc = 'Debug last Go test' },
      { '<leader>dt', function() require('dap-go').debug_test() end,      desc = 'Debug Go test' },
      { '<leader>rl', function() require('dap-go').run_last() end,        desc = 'Run last Go test' },
    },
    config = true,
    dependencies = 'mfussenegger/nvim-dap',
    ft = 'go',
  },

  {
    'suketa/nvim-dap-ruby', -- An extension for nvim-dap providing configurations for launching debug.rb
    config = true,
    dependencies = 'mfussenegger/nvim-dap',
    ft = 'ruby',
  },

  {
    'mfussenegger/nvim-dap',
    cmd = { 'BreakpointToggle', 'Debug', 'DapREPL' },
    dependencies = {
      {
        'theHamsta/nvim-dap-virtual-text',
        dependencies = 'nvim-treesitter/nvim-treesitter',
        config = true
      },
      {
        'rcarriga/nvim-dap-ui', --  A UI for nvim-dap
        keys = {
          { '<leader>de',  function() require('dapui').eval() end,    mode = 'v',            desc = 'Evaluate with DAP' },
          { '<leader>dui', function() require('dapui').toggle() end,  desc = 'Toggle DAP UI' },
          { '<leader>dro', function() require('dap').repl.open() end, desc = 'Open REPL' },
        },
        config = function()
          require('dapui').setup()
        end,
      }
    },
    keys = {
      { '<S-F5>', function() require('dap').close() end,             desc = 'Close DAP' },
      { '<F5>',   function() require('dap').continue() end,          desc = 'Continue execution' },
      { '<F7>',   function() require('dap').step_into() end,         desc = 'Step into' },
      { '<F8>',   function() require('dap').step_over() end,         desc = 'Step over' },
      { '<F9>',   function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
    },
    init = function()
      local m = require('mapx')

      m.nname('<leader>d', 'Debug')
    end,
    config = function()
      local dap = require('dap')

      -- Needs bash-debug-adapter installed (:MasonInstall bash-language-server)
      dap.adapters.bashdb = {
        type = 'executable',
        command = vim.fn.stdpath('data') .. '/mason/packages/bash-debug-adapter/bash-debug-adapter',
        name = 'bashdb',
      }

      local sh_config = {
        {
          type = 'bashdb',
          request = 'launch',
          name = 'Launch file',
          showDebugOutput = false,
          pathBashdb = vim.fn.stdpath('data') .. '/mason/packages/bash-debug-adapter/extension/bashdb_dir/bashdb',
          pathBashdbLib = vim.fn.stdpath('data') .. '/mason/packages/bash-debug-adapter/extension/bashdb_dir',
          trace = true,
          file = '${file}',
          program = '${file}',
          cwd = '${workspaceFolder}',
          pathCat = 'cat',
          pathBash = vim.fn.system('which bash'):gsub('\n[^\n]*$', ''),
          pathMkfifo = 'mkfifo',
          pathPkill = 'pkill',
          args = {},
          env = {},
          terminalKind = 'integrated',
        }
      }

      dap.configurations.sh = sh_config
      dap.configurations.zsh = sh_config

      -- Needs debug-py installed (:MasonInstall debug-py)
      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch file',
          program = '${file}',
          pythonPath = function()
            return vim.fn.system('which python'):gsub('\n[^\n]*$', '');
          end,
        },
      }

      vim.fn.sign_define('DapBreakpoint', { text = '🛑', texthl = '', linehl = '', numhl = '' })
    end
  }
}
