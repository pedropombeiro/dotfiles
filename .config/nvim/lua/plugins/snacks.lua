-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

local function yadm_repo()
  return vim.fn.expand("~/.local/share/yadm/repo.git") -- hardcode value of vim.fn.systemlist("yadm introspect repo")[1] for startup speed
end

local function lazygit_opts()
  local opts = {
    enabled = not vim.g.started_by_firenvim,
    configure = false,
    args = {
      "--use-config-dir", vim.fn.expand("~/.config/lazygit")
    }
  }

  if opts.enabled then
    local cwd = vim.fn.getcwd()
    local homedir = vim.fn.expand("~")
    local configdir = vim.fn.expand("~/.config")

    if cwd == homedir or string.sub(cwd, 1, #configdir) == configdir then
      vim.list_extend(opts.args, {
        "--git-dir", yadm_repo(),
        "--work-tree", homedir,
      })
    end
  end

  return opts
end

local function git_grep()
  -- Workaround until https://github.com/folke/snacks.nvim/issues/1184 is implemented
  local opts = lazygit_opts()
  if #opts.args > 2 then vim.env.GIT_DIR = opts.args[4] end

  Snacks.picker.git_grep()
end

local function yadm_grep()
  -- Workaround until https://github.com/folke/snacks.nvim/issues/1184 is implemented
  vim.env.GIT_DIR = yadm_repo()

  Snacks.picker.git_grep({ cwd = vim.fn.expand("~") })
end

---@format disable-next
-- stylua: ignore
---@type LazyKeysSpec[]
local keys = {
  { "<leader>b", group = "Bclose" },
  { "<leader>bd", function() Snacks.bufdelete() end, desc = "Close buffer", silent = true },

  { "<leader>fn", function() Snacks.dashboard.open() end, desc = "Dashboard", silent = true },

  { "<leader>fn", function() Snacks.notifier.show_history() end, desc = "Notification History", silent = true },
  { "<leader>dn", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications", silent = true },

  { "<leader>tn", function() Snacks.terminal() end, desc = "Open terminal", silent = true },

  { "<leader>-", function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
  { "<leader>S", function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },

  { "[w", function() Snacks.words.jump(-1, true) end, desc = "Previous word reference", silent = true },
  { "]w", function() Snacks.words.jump(1, true) end, desc = "Next word reference", silent = true },

  -- File operations
  { "<leader>f", group = "Picker" },
  { "<leader>ff", function() Snacks.picker.files() end, desc = "Files", icon = "" },
  { "<leader>fr", function() Snacks.picker.grep() end, desc = "Live grep (rg)", icon = "" },
  { "<leader>fF", function() Snacks.picker.resume() end, desc = "Resume last finder query" },
  { "<leader><Tab>", function() Snacks.picker.keymaps() end, desc = "Keymaps", icon = "" },
  { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
  { "<leader>fH", function() Snacks.picker.highlights() end, desc = "Highlight groups" },
  { "<leader>fK", function() Snacks.picker.man() end, desc = "Man pages", icon = "" },
  { "<leader>fl", function() Snacks.picker.loclist() end, desc = "Location list", icon = "" },
  { "<leader>fq", function() Snacks.picker.qflist() end, desc = "Quickfix list", icon = "" },
  -- { "<leader>fT",    "<Cmd>Telescope filetypes<CR>",       desc = "Filetypes" },
  { "<leader>fh", function() Snacks.picker.recent() end, desc = "Old files" },
  { "<leader>f:", function() Snacks.picker.command_history() end, desc = "Command history", icon = "" },
  { "<leader>f/", function() Snacks.picker.search_history() end, desc = "Search history", icon = "󱝩" },
  {
    "<leader>fd",
    function() Snacks.picker.diagnostics() end,
    desc = "Diagnostics",
    icon = require("config").ui.icons.diagnostics.warning,
  },
  { "<leader>f`", function() Snacks.picker.marks() end, desc = "Marks", icon = "" },
  { "<leader>f'", function() Snacks.picker.marks() end, desc = "Marks", icon = "" },
  { "<leader>f.", function() Snacks.picker.jumps() end, desc = "Jump list", icon = "" },
  { '<leader>f"', function() Snacks.picker.registers() end, desc = "Registers" },
  -- { "<leader>fO",    "<Cmd>Telescope vim_options<CR>",     desc = "Vim options" },
  { "<leader>fs", function() Snacks.picker.spelling() end, desc = "Spelling suggestions", icon = "󱣩" },
  { "<leader>fS", function() Snacks.picker() end, desc = "Pickers", icon = "" },
  { "<leader>fp", function() Snacks.picker.lazy() end, desc = "Plugins", icon = "" },

  -- Git operations
  { "<leader>fg", group = "Finder (Git)" },
  { "<leader>fgb", function() Snacks.picker.git_branches() end, desc = "Git branches", icon = "" },
  { "<leader>fgc", function() Snacks.picker.git_log() end, desc = "Git commits", icon = "" },
  { "<leader>fgC", function() Snacks.picker.git_log_file() end, desc = "Git commits (buffer)", icon = "" },
  { "<leader>/", function() git_grep() end, desc = "Git grep", icon = "󰛔" },
  { "<leader>fgg", function() git_grep() end, desc = "Git grep", icon = "󰛔" },
  { "<leader>fgy", function() yadm_grep() end, desc = "YADM grep", icon = "󰛔" },
  { "<leader>fgf", function() Snacks.picker.git_files() end, desc = "Git files", icon = "" },
  { "<leader>fgS", function() Snacks.picker.git_stash() end, desc = "Git stash" },
  { "<leader>fgs", function() Snacks.picker.git_status() end, desc = "Git status", icon = "󱖫" },
  -- LSP operations
  { "<leader>l", group = "Finder (LSP)" },
  { "<leader>ls", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
  { "<leader>lr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
  { "<leader>ld", function() Snacks.picker.lsp_definitions() end, desc = "Definitions" },
  { "<C-]>", function() Snacks.picker.lsp_definitions() end, desc = "Definitions" },
  { "<leader>lt", function() Snacks.picker.lsp_type_definitions() end, desc = "Typedefs" },
  { "<leader>lw", group = "Workspace" },
  { "<leader>lws", function() Snacks.picker.lsp_symbols({ workspace = true }) end, desc = "Workspace symbols" },
  -- { "<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>",           desc = "Code actions" },

  { "<C-e>", function() Snacks.picker.icons() end, desc = "Emojis", mode = "i", icon = "" },

  -- LazyGit
  {
    "<leader>tg",
    function()
      Snacks.lazygit.open(lazygit_opts())

      local plugins = require("lazy.core.config").plugins
      if plugins["gitsigns.nvim"] ~= nil and plugins["gitsigns.nvim"]._.loaded ~= nil then
        -- ensure that Gitsigns refreshes with new state after closing Lazygit
        vim.cmd([[execute 'Gitsigns refresh']])
      end
    end,
    desc = "Open LazyGit",
  },
}

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  init = function() require("which-key").add(keys) end,
  opts = function()
    local config = require("config")
    local icons = config.ui.icons.diagnostics
    local function vim_version() return vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch end

    Set_hl(
      { InputBorder = { bg = config.theme.colors.dark0, fg = config.theme.colors.orange } },
      { prefix = "SnacksPicker", default = true }
    )

    ---@type snacks.Config
    return {
      bigfile = {
        enabled = not vim.g.started_by_firenvim,
      },
      dashboard = {
        enabled = not vim.g.started_by_firenvim,
        preset = {
          header = [[
      ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ]]
            .. vim_version()
            .. "\n"
            .. [[
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        },
        sections = {
          { section = "header" },
          { pane = 2, section = "terminal", cmd = "curl -s 'https://wttr.in/?0' || echo", height = 8 },
          {
            { icon = " ", key = "f", desc = "Find File", action = function() Snacks.dashboard.pick("files") end },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            {
              icon = " ",
              key = "g",
              desc = "Find Text",
              action = function() Snacks.dashboard.pick("live_grep") end,
            },
            { icon = " ", key = "<leader>/", desc = "Git Grep", action = function() git_grep() end },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            {
              icon = " ",
              key = "c",
              desc = "Config",
              action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
            },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            {
              icon = "󰒲 ",
              key = "l",
              desc = "Lazy",
              action = function() require("lazy").home() end,
              enabled = package.loaded.lazy ~= nil,
            },
            { icon = " ", key = "m", desc = "Mason", action = ":Mason" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa", padding = 1 },
          },
          { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 2 },
          { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
          {
            pane = 2,
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function() return Snacks.git.get_root() ~= nil end,
            cmd = "git --no-pager diff --stat -B -M -C",
            padding = 1,
            ttl = 5 * 60,
            indent = 2,
          },
          { section = "startup" },
        },
      },
      image = { enabled = false },
      indent = {
        animate = {
          duration = {
            step = 20, -- ms per step
            total = 200, -- maximum duration
          },
        },
      },
      input = {
        enabled = true,
      },
      lazygit = lazygit_opts(),
      notifier = {
        enabled = true,
        timeout = 3000,
        icons = {
          error = icons.error,
          warn = icons.warning,
          info = icons.info,
          debug = icons.debug,
          trace = icons.trace,
        },
      },
      quickfile = {
        enabled = true,
      },
      picker = {
        layout = {
          cycle = true,
          reverse = true,
          layout = {
            box = "vertical",
            backdrop = false,
            width = 0.7,
            height = 0.8,
            border = "none",
            {
              win = "preview",
              title = "{preview:Preview}",
              border = "rounded",
              title_pos = "center",
            },
            {
              box = "vertical",
              { win = "list", title = " Results ", title_pos = "center", border = "rounded" },
              { win = "input", height = 1, border = "rounded", title = "{title} {live} {flags}", title_pos = "center" },
            },
          },
        },
        sources = {
          explorer = {
            git_untracked = false,
          },
        },
        on_show = function()
          require("nvim-treesitter") -- Ensure treesitter is loaded for correct code preview colors
        end,
      },
      scope = {
        enabled = true,
      },
      scratch = {
        enabled = true,
      },
      statuscolumn = {
        left = { "mark", "fold", "sign" }, -- priority of signs on the left (high to low)
        right = { "git" }, -- priority of signs on the right (high to low)
        folds = {
          open = false, -- show open fold icons
          git_hl = true, -- use Git Signs hl for fold icons
        },
        git = {
          -- patterns to match Git signs
          patterns = { "GitSign" },
        },
        refresh = 50, -- refresh at most every 50ms
      },
      terminal = {
        enabled = not vim.g.started_by_firenvim,
      },
      win = {
        border = "rounded",
      },
      words = {
        enabled = true,
        notify_jump = true,
      },
    }
  end,
}
