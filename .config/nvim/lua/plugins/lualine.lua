-- lualine.nvim (https://github.com/nvim-lualine/lualine.nvim)
--  A blazing fast and easy to configure neovim statusline plugin written in pure lua.

return {
  {
    "nvim-lualine/lualine.nvim",
    event = { "BufNewFile", "BufReadPost" },
    dependencies = {
      "kyazdani42/nvim-web-devicons",
      "nvim-lua/plenary.nvim", -- Used by update_gstatus()
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

      local gstatus = { ahead = 0, behind = 0 }
      local function update_gstatus()
        local ok, Job = pcall(require, "plenary.job")
        if not ok then return end
        Job:new({
          command = "git",
          args = { "rev-list", "--left-right", "--count", "HEAD...@{upstream}" },
          on_exit = function(job, _)
            local res = job:result()[1]
            if type(res) ~= "string" then
              gstatus = { ahead = 0, behind = 0 }
              return
            end
            local match_ok, ahead, behind = pcall(string.match, res, "(%d+)%s*(%d+)")
            if match_ok then
              ahead, behind = tonumber(ahead), tonumber(behind)
            else
              ahead, behind = 0, 0
            end
            gstatus = { ahead = ahead, behind = behind }
          end,
        }):start()
      end

      -- Defer timer start to avoid blocking startup
      vim.defer_fn(function()
        if _G.Gstatus_timer == nil then
          _G.Gstatus_timer = vim.uv.new_timer()
        else
          _G.Gstatus_timer:stop()
        end
        _G.Gstatus_timer:start(0, 30000, vim.schedule_wrap(update_gstatus))
      end, 100)

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
            {
              function() return "⊛ YADM" end,
              cond = function() return vim.b.yadm_tracked == true end,
            },
            { "b:gitsigns_head", icon = "" },
            {
              function()
                local parts = {}
                if gstatus.behind > 0 then table.insert(parts, gstatus.behind .. "↓") end
                if gstatus.ahead > 0 then table.insert(parts, gstatus.ahead .. "↑") end
                return table.concat(parts, " ")
              end,
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
            {
              "overseer",
              label = "", -- Prefix for task counts
              colored = true, -- Color the task icons and counts
              symbols = {
                [require("overseer").STATUS.FAILURE] = config.ui.icons.tests.failed .. ":",
                [require("overseer").STATUS.CANCELED] = config.ui.icons.tests.canceled .. ":",
                [require("overseer").STATUS.SUCCESS] = config.ui.icons.tests.passed .. ":",
                [require("overseer").STATUS.RUNNING] = config.ui.icons.tests.running .. ":",
              },
              unique = false, -- Unique-ify non-running task count by name
              name = nil, -- List of task names to search for
              name_not = false, -- When true, invert the name search
              status = nil, -- List of task statuses to display
              status_not = false, -- When true, invert the status search
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
