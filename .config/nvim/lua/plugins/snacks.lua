-- snacks.nvim (https://github.com/folke/snacks.nvim)
--  🍿 A collection of QoL plugins for Neovim

---@type pmsp.neovim.Config
local config = require("config")

local function yadm_repo()
  return vim.fn.expand("~/.local/share/yadm/repo.git") -- hardcode value of vim.fn.systemlist("yadm introspect repo")[1] for startup speed
end

local function is_yadm_repo()
  local cwd = vim.fn.getcwd()
  local homedir = vim.fn.expand("~")
  local configdir = vim.fn.expand("~/.config")

  return cwd == homedir or string.sub(cwd, 1, #configdir) == configdir
end

local function yadm_opts()
  return {
    "--git-dir",
    yadm_repo(),
    "--work-tree",
    vim.fn.expand("~"),
  }
end

local function git_opts()
  if is_yadm_repo() then return yadm_opts() end

  return {}
end

---@type function|snacks.lazygit.Config
local function lazygit_opts()
  local opts = {
    enabled = not vim.g.started_by_firenvim,
    configure = false,
    args = {
      "--use-config-dir",
      vim.fn.expand("~/.config/lazygit"),
    },
  }

  if opts.enabled then vim.list_extend(opts.args, git_opts()) end

  return opts
end

local function with_git_dir(fn, title)
  if is_yadm_repo() then
    fn({ cwd = vim.fn.expand("~"), args = yadm_opts(), title = title:gsub("Git", "YADM") })
    return
  end

  fn()
end

local function yadm_grep() Snacks.picker.git_grep({ title = "YADM Grep", cwd = vim.fn.expand("~"), args = yadm_opts() }) end

---@format disable-next
-- stylua: ignore
---@type wk.Spec
local keys = {
  { "<leader>b", group = "Bclose" },
  { "<leader>bd", function() Snacks.bufdelete() end, desc = "Close buffer", silent = true },

  { "<leader>fn", function() Snacks.notifier.show_history() end, desc = "Notification History", silent = true },
  { "<leader>dn", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications", silent = true },

  { "<leader>tn", function() Snacks.terminal() end, desc = "Open terminal", silent = true },

  { "<leader>D", function() Snacks.dashboard.open() end, desc = "Dashboard", silent = true },
  { "<leader>-", function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
  { "<leader>S", function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },

  { "[w", function() Snacks.words.jump(-1, true) end, desc = "Previous word reference", silent = true },
  { "]w", function() Snacks.words.jump(1, true) end, desc = "Next word reference", silent = true },

  { "<C-\\>", function() Snacks.explorer.reveal() end, mode = { "n", "v" }, desc = "Toggle file explorer" },

  -- File operations
  { "<leader>f", group = "Picker" },
  { "<leader>ff", function() Snacks.picker.files() end, desc = "Files", icon = "" },
  { "<leader>fr", function() Snacks.picker.grep() end, desc = "Live grep (rg)", icon = "" },
  { "<leader>fF", function() Snacks.picker.resume() end, desc = "Resume last finder query" },
  { "<leader><Tab>", function() Snacks.picker.keymaps() end, desc = "Keymaps", icon = "" },
  { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
  { "<leader>fc", function() Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')}) end, desc = "Neovim Config" },
  { "<leader>fH", function() Snacks.picker.highlights() end, desc = "Highlight groups" },
  { "<leader>fK", function() Snacks.picker.man() end, desc = "Man pages", icon = "" },
  { "<leader>fl", function() Snacks.picker.loclist() end, desc = "Location list", icon = "" },
  { "<leader>fq", function() Snacks.picker.qflist() end, desc = "Quickfix list", icon = "" },
  -- { "<leader>fT",    "<Cmd>Telescope filetypes<CR>",       desc = "Filetypes" },
  { "<leader>fh", function() Snacks.picker.recent() end, desc = "Old files" },
  { "<leader>f:", function() Snacks.picker.command_history() end, desc = "Command history", icon = "" },
  { "<leader>f/", function() Snacks.picker.search_history() end, desc = "Search history", icon = "󱝩" },
  { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics", icon = "" },
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
  { "<leader>fgb", function() with_git_dir(Snacks.picker.git_branches, "Git Branches") end, desc = "Git branches", icon = "" },
  { "<leader>fgc", function() with_git_dir(Snacks.picker.git_log, "Git Log") end, desc = "Git commits", icon = "" },
  { "<leader>fgC", function() with_git_dir(Snacks.picker.git_log_file, "Git Log File") end, desc = "Git commits (buffer)", icon = "" },
  { "<leader>/", function() with_git_dir(Snacks.picker.git_grep, "Git Grep") end, desc = "Git grep", icon = "󰛔" },
  { "<leader>fgg", function() with_git_dir(Snacks.picker.git_grep, "Git Grep") end, desc = "Git grep", icon = "󰛔" },
  { "<leader>fgy", function() yadm_grep() end, desc = "YADM grep", icon = "󰛔" },
  { "<leader>fgf", function() with_git_dir(Snacks.picker.git_files, "Git Files") end, desc = "Git files", icon = "" },
  { "<leader>fgS", function() with_git_dir(Snacks.picker.git_stash, "Git Stash") end, desc = "Git stash" },
  { "<leader>fgs", function() with_git_dir(Snacks.picker.git_status, "Git Status") end, desc = "Git status", icon = "󱖫" },
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
  opts = function()
    local diagnostics_icons = config.ui.icons.diagnostics
    ---@return string
    local function vim_version() return vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch end

    Set_hl(
      { InputBorder = { bg = config.theme.colors.dark0, fg = config.theme.colors.orange } },
      { prefix = "SnacksPicker", default = true }
    )

    ---@diagnostic disable: missing-fields
    ---@type snacks.Config
    return {
      bigfile = { enabled = not vim.g.started_by_firenvim },
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
            { icon = " ", key = "f", desc = "Find File", action = ':lua Snacks.dashboard.pick("files")' },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text", action = ':lua Snacks.dashboard.pick("live_grep")' },
            {
              icon = " ",
              key = "<leader>/",
              desc = "Git Grep",
              action = function() with_git_dir(Snacks.picker.git_grep, "Git Grep") end,
            },
            { icon = " ", key = "r", desc = "Recent Files", action = ':lua Snacks.dashboard.pick("oldfiles")' },
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
              action = ':lua require("lazy").home()',
              enabled = package.loaded.lazy ~= nil,
            },
            { icon = " ", key = "m", desc = "Mason", action = ":Mason" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa", padding = 1 },
          },
          { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 2 },
          { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
          {
            pane = 2,
            icon = " ",
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
      explorer = {
        enabled = function() return not vim.g.started_by_firenvim end,
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
      input = { enabled = true },
      lazygit = lazygit_opts(),
      notifier = {
        enabled = true,
        timeout = 3000,
        icons = {
          error = diagnostics_icons.error,
          warn = diagnostics_icons.warning,
          info = diagnostics_icons.info,
          debug = diagnostics_icons.debug,
          trace = diagnostics_icons.trace,
        },
      },
      quickfile = { enabled = true },
      picker = {
        jump = {
          reuse_win = true, -- reuse an existing window if the buffer is already open
        },
        icons = {
          files = {
            enabled = true, -- show file icons
            dir = config.ui.icons.folder.collapsed .. " ",
            dir_open = config.ui.icons.folder.expanded .. " ",
            file = config.ui.icons.kinds.File .. " ",
          },
          git = {
            enabled = true, -- show git icons
            staged = config.ui.icons.symbols.staged,
            added = config.ui.icons.symbols.added,
            deleted = config.ui.icons.symbols.removed,
            modified = config.ui.icons.symbols.modified,
            renamed = config.ui.icons.symbols.renamed,
          },
          diagnostics = {
            Error = diagnostics_icons.error .. " ",
            Warn = diagnostics_icons.warning .. " ",
            Info = diagnostics_icons.info .. " ",
            Hint = diagnostics_icons.info .. " ",
          },
        },
        layout = { preset = "popup" },
        layouts = {
          right = {
            layout = { position = "right" },
          },
          popup = {
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
                border = config.ui.border,
                title_pos = "center",
              },
              {
                box = "vertical",
                { win = "list", title = " Results ", title_pos = "center", border = config.ui.border },
                {
                  win = "input",
                  height = 1,
                  border = config.ui.border,
                  title = "{title} {live} {flags}",
                  title_pos = "center",
                },
              },
            },
          },
        },
        matcher = {
          frecency = true,
        },
        previewers = {
          diff = {
            builtin = true,
            cmd = { "delta" },
          },
          git = {
            args = git_opts(),
          },
        },
        sources = {
          explorer = {
            exclude = {
              "*.zwc",
              ".DS_Store",
              "thumbs.db",
            },
            git_untracked = false,
            hidden = true,
            layout = {
              preset = "right",
              preview = { main = true, enabled = false },
            },
            win = {
              list = {
                keys = {
                  ["C"] = "explorer_close", -- close directory
                },
              },
            },
          },
        },
        on_show = function()
          require("nvim-treesitter") -- Ensure treesitter is loaded for correct code preview colors
        end,
      },
      scope = { enabled = true },
      scratch = { enabled = true },
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
      terminal = { enabled = not vim.g.started_by_firenvim },
      win = {
        border = config.ui.border,
      },
      words = {
        notify_jump = true,
      },
    }
  end,
  specs = {
    {
      "folke/which-key.nvim",
      opts = {
        ---@module "which-key"
        ---@type wk.Spec
        spec = keys,
      },
      opts_extend = { "spec" },
    },
  },
}
