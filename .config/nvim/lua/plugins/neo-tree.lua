-- neo-tree.lua (https://github.com/nvim-neo-tree/neo-tree.nvim)
--  Neovim plugin to manage the file system and other tree like structures.

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v2.x",
  cond = function() return not vim.g.started_by_firenvim end,
  cmd = "Neotree",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "kyazdani42/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
  },
  keys = {
    {
      "<C-\\>",
      "<Cmd>Neotree filesystem toggle reveal position=right<CR>",
      mode = { "n", "v" },
      desc = "Toggle file explorer"
    },
    {
      "gx", -- Restore URL handling from disabled netrw plugin
      function()
        if vim.fn.has("mac") == 1 then
          vim.cmd [[call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>]]
        elseif vim.fn.has("unix") == 1 then
          vim.cmd [[call jobstart(["xdg-open", expand("<cfile>")], {"detach": v:true})<CR>]]
        else
          print("Error: gx is not supported on this OS!")
        end
      end,
      "Open URL"
    },
  },
  init = function()
    vim.g.neo_tree_remove_legacy_commands = 1
    if vim.fn.argc() == 1 then
      local stat = vim.loop.fs_stat(vim.fn.argv(0))
      if stat and stat.type == "directory" then
        require("neo-tree")
      end
    end
  end,
  config = function()
    local config = require("config")

    ---@diagnostic disable: undefined-field
    vim.fn.sign_define("DiagnosticSignError", { text = config.icons.diagnostics.error, texthl = "DiagnosticSignError" })
    vim.fn.sign_define("DiagnosticSignWarn", { text = config.icons.diagnostics.warning, texthl = "DiagnosticSignWarn" })
    vim.fn.sign_define("DiagnosticSignInfo", { text = config.icons.diagnostics.info, texthl = "DiagnosticSignInfo" })
    vim.fn.sign_define("DiagnosticSignHint", { text = config.icons.diagnostics.hint, texthl = "DiagnosticSignHint" })
    ---@diagnostic enable: undefined-field

    require("neo-tree").setup({
      default_component_configs = {
        icon = {
          ---@diagnostic disable: undefined-field
          folder_closed = config.icons.folder.collapsed,
          folder_open   = config.icons.folder.expanded
          ---@diagnostic enable: undefined-field
        },
        indent = {
          ---@diagnostic disable: undefined-field
          expander_collapsed = config.icons.expander.collapsed,
          expander_expanded = config.icons.expander.expanded,
          ---@diagnostic enable: undefined-field
        },
      },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_hidden = true, -- only works on Windows for hidden files/directories
          hide_by_name = {
            ".git",
            "node_modules",
          },
          hide_by_pattern = { -- uses glob style patterns
            "*.zwc",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            ".DS_Store",
            "thumbs.db"
          },
        }
      },
      window = {
        position = "right",
        mappings = {
          ["<space>"] = "none",
        },
      },
    })
  end,
  deactivate = function()
    vim.cmd([[Neotree close]])
  end,
}
