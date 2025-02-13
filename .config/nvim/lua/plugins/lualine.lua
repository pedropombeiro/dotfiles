-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

return {
  "nvim-lualine/lualine.nvim",
  event = { "BufNewFile", "BufReadPost" },
  dependencies = {
    "kyazdani42/nvim-web-devicons",
  },
  init = function()
    local opt = vim.opt

    opt.showmode = false -- The mode is shown in Lualine anyway
    opt.showcmd = false -- The selected line count is already shown in Lualine
    if vim.fn.has("nvim-0.9") == 1 then
      opt.shortmess:append({ S = true }) -- do not show search count message when searching
    end
  end,
  opts = function()
    local config = require("config")
    local diagnostic_icons = config.ui.icons.diagnostics
    local symbol_icons = config.ui.icons.symbols
    local sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch" },
      lualine_c = {
        {
          "diagnostics",
          sources = { "nvim_lsp", "nvim_diagnostic" },
          symbols = {
            ---@diagnostic disable: undefined-field
            hint = diagnostic_icons.hint .. " ",
            info = diagnostic_icons.info .. " ",
            warn = diagnostic_icons.warning .. " ",
            error = diagnostic_icons.error .. " ",
            ---@diagnostic enable: undefined-field
          },
        },
        {
          "filetype",
          cond = function() return not vim.g.started_by_firenvim end,
          icon_only = true,
          separator = "",
          padding = { left = 1, right = 0 },
        },
        {
          "filename",
          cond = function() return not vim.g.started_by_firenvim end,
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
          cond = function() return not vim.g.started_by_firenvim end,
        },
        {
          "diff",
          cond = function() return not vim.g.started_by_firenvim end,
          symbols = {
            ---@diagnostic disable: undefined-field
            added = symbol_icons.added .. " ",
            modified = symbol_icons.modified .. " ",
            removed = symbol_icons.removed .. " ",
            ---@diagnostic enable: undefined-field
          },
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
    }

    return {
      options = {
        icons_enabled = true,
        ignore_focus = { "neotest-summary", "lazygit", "TelescopePrompt", "Outline" },
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
        "neo-tree",
      },
      sections = sections,
    }
  end,
}
