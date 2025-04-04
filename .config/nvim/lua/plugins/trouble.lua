-- trouble.nvim (https://github.com/folke/trouble.nvim)
--  🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all
--  the trouble your code is causing.

return {
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    ---@diagnostic disable: missing-fields
    ---@type LazyKeysSpec[]
    keys = {
      { "<leader>xw", "<cmd>Trouble diagnostics toggle<cr>", desc = "Toggle workspace diagnostics" },
      { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Toggle document diagnostics" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Toggle quickfix window" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Toggle loclist window" },
      {
        "[X",
        function() require("trouble").first({ jump = true }) end,
        desc = "First Trouble/Quickfix 🚦 item",
      },
      {
        "[x",
        function()
          if require("trouble").is_open() then
            require("trouble").prev({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then vim.notify(err, vim.log.levels.ERROR) end
          end
        end,
        desc = "Previous Trouble/Quickfix 🚦 item",
      },
      {
        "]x",
        function()
          if require("trouble").is_open() then
            require("trouble").next({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then vim.notify(err, vim.log.levels.ERROR) end
          end
        end,
        desc = "Next Trouble/Quickfix 🚦 item",
      },
      {
        "]X",
        function() require("trouble").last({ jump = true }) end,
        desc = "Last Trouble/Quickfix 🚦 item",
      },
    },
    opts = {
      use_diagnostic_signs = true,
      preview = {
        type = "main",
        -- when a buffer is not yet loaded, the preview window will be created
        -- in a scratch buffer with only syntax highlighting enabled.
        -- Set to false, if you want the preview to always be a real loaded buffer.
        scratch = false,
      },
    },
    config = function(_, opts)
      Set_hl({ TroubleNormal = { link = "NormalFloat" } })

      require("trouble").setup(opts)
    end,
    specs = {
      {
        "folke/snacks.nvim",
        opts = function(_, opts)
          return vim.tbl_deep_extend("force", opts or {}, {
            picker = {
              actions = require("trouble.sources.snacks").actions,
              win = {
                input = {
                  keys = {
                    ["<c-t>"] = {
                      "trouble_open",
                      mode = { "n", "i" },
                    },
                  },
                },
              },
            },
          })
        end,
      },
      {
        "folke/which-key.nvim",
        opts = {
          ---@module "which-key"
          ---@type wk.Spec
          spec = {
            { "<leader>x", group = "Trouble", icon = "🚦" },
          },
        },
      },
    },
  },
  { "kyazdani42/nvim-web-devicons", lazy = true },
}
