-- neo-tree.lua (https://github.com/nvim-neo-tree/neo-tree.nvim)
--  Neovim plugin to manage the file system and other tree like structures.

---@type pmsp.neovim.Config
local config = require("config")
local icons = config.ui.icons

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cond = function() return not vim.g.started_by_firenvim end,
    cmd = "Neotree",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      {
        "<C-\\>",
        "<Cmd>Neotree filesystem toggle reveal position=right<CR>",
        mode = { "n", "v" },
        desc = "Toggle file explorer",
      },
    },
    init = function()
      vim.g.neo_tree_remove_legacy_commands = 1

      -- FIX: use `autocmd` for lazy-loading neo-tree instead of directly requiring it,
      -- because `cwd` is not set up properly.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
        desc = "Start Neo-tree with directory",
        once = true,
        callback = function()
          if package.loaded["neo-tree"] then
            return
          else
            local stats = vim.uv.fs_stat(vim.fn.argv(0))
            if stats and stats.type == "directory" then require("neo-tree") end
          end
        end,
      })
    end,
    opts = {
      popup_border_style = config.ui.border,
      default_component_configs = {
        diagnostics = {
          symbols = {
            error = icons.diagnostics.error,
            warn = icons.diagnostics.warning,
            info = icons.diagnostics.info,
            hint = icons.diagnostics.hint,
          },
        },
        icon = {
          folder_empty = icons.folder.empty,
          folder_empty_open = icons.folder.empty_open,
          folder_closed = icons.folder.collapsed,
          folder_open = icons.folder.expanded,
          default = "",
        },
        indent = {
          expander_collapsed = icons.expander.collapsed,
          expander_expanded = icons.expander.expanded,
          expander_highlight = "NeoTreeExpander",
        },
        modified = {
          symbol = icons.symbols.modified,
        },
        git_status = {
          symbols = {
            -- Change type
            deleted = icons.symbols.removed, -- this can only be used in the git_status source
            renamed = icons.symbols.renamed, -- this can only be used in the git_status source
            -- Status type
            staged = icons.symbols.staged,
            unstaged = icons.symbols.unstaged,
          },
        },
      },
      document_symbols = {
        kinds = {
          File = { icon = "󰈙", hl = "Tag" },
          Namespace = { icon = icons.kinds.Namespace, hl = "Include" },
          Package = { icon = icons.kinds.Package, hl = "Label" },
          Class = { icon = icons.kinds.Class, hl = "Include" },
          Property = { icon = icons.kinds.Property, hl = "@property" },
          Enum = { icon = icons.kinds.Enum, hl = "@number" },
          Function = { icon = icons.kinds.Function, hl = "Function" },
          String = { icon = icons.kinds.String, hl = "String" },
          Number = { icon = icons.kinds.Number, hl = "Number" },
          Array = { icon = icons.kinds.Array, hl = "Type" },
          Object = { icon = icons.kinds.Object, hl = "Type" },
          Key = { icon = icons.kinds.Key, hl = "" },
          Struct = { icon = icons.kinds.Struct, hl = "Type" },
          Operator = { icon = icons.kinds.Operator, hl = "Operator" },
          TypeParameter = { icon = icons.kinds.TypeParameter, hl = "Type" },
          StaticMethod = { icon = "󰠄 ", hl = "Function" },
        },
      },
      sources = { "filesystem", "buffers", "git_status", "document_symbols" },
      open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "Outline", "trouble" },
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = "disabled",
        use_libuv_file_watcher = true,
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
            "thumbs.db",
          },
        },
        find_args = {
          fd = {
            "-uu",
            "--exclude",
            ".git",
            "--exclude",
            "node_modules",
            "--exclude",
            "target",
          },
        },
      },
      window = {
        position = "right",
        mappings = {
          ["<space>"] = "none",
        },
      },
    },
    config = function(_, opts)
      -- +Snacks
      local function on_move(data) Snacks.rename.on_rename_file(data.source, data.destination) end
      local events = require("neo-tree.events")
      opts.event_handlers = opts.event_handlers or {}
      vim.list_extend(opts.event_handlers, {
        { event = events.FILE_MOVED, handler = on_move },
        { event = events.FILE_RENAMED, handler = on_move },
      })
      -- -Snacks

      require("neo-tree").setup(opts)

      -- refresh neotree git status when closing a lazygit terminal
      vim.api.nvim_create_autocmd("TermClose", {
        pattern = "*lazygit",
        callback = function()
          if package.loaded["neo-tree.sources.git_status"] then require("neo-tree.sources.git_status").refresh() end
        end,
      })
    end,
    deactivate = function() vim.cmd([[Neotree close]]) end,
  },
  { "nvim-lua/plenary.nvim", lazy = true },
  {
    "kyazdani42/nvim-web-devicons", -- not strictly required, but recommended
    lazy = true,
  },
  {
    "s1n7ax/nvim-window-picker",
    name = "window-picker",
    lazy = true,
    version = "2.*",
    opts = function()
      local colors = config.theme.colors

      return {
        use_winbar = "always",
        highlights = {
          statusline = {
            focused = {
              fg = colors.fg,
              bg = colors.orange_bg,
            },
            unfocused = {
              fg = colors.fg,
              bg = colors.green_bg,
            },
          },
          winbar = {
            focused = {
              fg = colors.fg,
              bg = colors.orange_bg,
            },
            unfocused = {
              fg = colors.fg,
              bg = colors.green_bg,
            },
          },
        },
      }
    end,
  },
}
