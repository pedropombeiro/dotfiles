-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

return {
  {
    "nvim-lualine/lualine.nvim",
    event = { "BufNewFile", "BufReadPost" },
    dependencies = {
      "kyazdani42/nvim-web-devicons",
      {
        -- A simple Neovim plugin providing a lualine component for displaying git status in the status line
        "abccsss/nvim-gitstatus",
        event = "VeryLazy",
        opts = {
          auto_fetch_interval = false,
        },
      },
    },
    opts = function()
      ---@type pmsp.neovim.Config
      local config = require("config")
      local diagnostic_icons = config.ui.icons.diagnostics
      local symbol_icons = config.ui.icons.symbols
      local opt = vim.opt

      opt.showmode = false -- The mode is shown in Lualine anyway
      opt.showcmd = false -- The selected line count is already shown in Lualine
      if vim.fn.has("nvim-0.9") == 1 then
        opt.shortmess:append({ S = true }) -- do not show search count message when searching
      end

      local function firenvim_cond() return not vim.g.started_by_firenvim end
      local function diff_source()
        local gitsigns = vim.b.gitsigns_status_dict
        if gitsigns then
          return {
            added = gitsigns.added,
            modified = gitsigns.changed,
            removed = gitsigns.removed,
          }
        end
      end

      return {
        options = {
          icons_enabled = true,
          ignore_focus = {
            "Outline",
            "lazygit",
            "neotest-summary",
            "snacks_picker_input",
            "snacks_picker_list",
          },
          disabled_filetypes = {
            statusline = { "snacks_dashboard", "Fm", "mason", "neotest-summary" },
          },
          globalstatus = true,
          theme = "gruvbox",
        },
        extensions = {
          "fugitive",
          "man",
          "lazy",
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = {
            { "b:gitsigns_head", icon = "" },
            {
              "gitstatus",
              sections = {
                { "ahead", format = "{}↑" },
                { "behind", format = "{}↓" },
              },
              sep = " ",
            },
            {
              "diff",
              cond = firenvim_cond,
              symbols = {
                added = symbol_icons.added .. " ",
                modified = symbol_icons.modified .. " ",
                removed = symbol_icons.removed .. " ",
              },
              source = diff_source,
            },
          },
          lualine_c = {
            {
              "diagnostics",
              sources = { "nvim_diagnostic" },
              symbols = {
                hint = diagnostic_icons.hint .. " ",
                info = diagnostic_icons.info .. " ",
                warn = diagnostic_icons.warning .. " ",
                error = diagnostic_icons.error .. " ",
              },
            },
            {
              "filetype",
              cond = firenvim_cond,
              icon_only = true,
              separator = "",
              padding = { left = 1, right = 0 },
            },
            {
              "filename",
              cond = firenvim_cond,
              show_filename_only = false,
              path = 1,
              shorting_target = 80,
              symbols = {
                modified = symbol_icons.modified,
                readonly = symbol_icons.readonly, -- Text to show when the file is non-modifiable or readonly.
              },
            },
          },
          lualine_x = {
            {
              require("lazy.status").updates,
              cond = require("lazy.status").has_updates,
            },
            {
              "pipeline", -- https://github.com/topaxi/pipeline.nvim
              cond = firenvim_cond,
            },
            "encoding",
            "fileformat",
            "filetype",
          },
          lualine_y = {
            "selectioncount",
            { "searchcount", maxcount = 999, timeout = 500 },
          },
          lualine_z = {
            "progress",
            "location",
          },
        },
      }
    end,
  },
}
