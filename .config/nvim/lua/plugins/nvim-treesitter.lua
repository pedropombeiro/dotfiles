-- nvim-treesitter (https://github.com/nvim-treesitter/nvim-treesitter)
--  Nvim Treesitter configurations and abstraction layer

-- A list of parser names, or "all"
local ensure_installed = {
  "bash",
  "diff",
  "dockerfile",
  "embedded_template",
  "git_config",
  "git_rebase",
  "gitcommit",
  "gitignore",
  "go",
  "gomod",
  "graphql",
  "html",
  "json",
  "lua",
  "make",
  "markdown",
  "markdown_inline",
  "python",
  "regex",
  "ruby",
  "sql",
  "ssh_config",
  "toml",
  "tmux",
  "vim",
  "vimdoc",
  "yaml",
}
local M = {}

M._installed = nil ---@type table<string,string>?

function M.get_installed(update)
  if update then
    M._installed = {}
    for _, lang in ipairs(require("nvim-treesitter").get_installed("parsers")) do
      M._installed[lang] = lang
    end
  end
  return M._installed or {}
end

---@param what string|number|nil
---@overload fun(buf?:number):boolean
---@overload fun(ft:string):boolean
---@return boolean
function M.have(what)
  what = what or vim.api.nvim_get_current_buf()
  what = type(what) == "number" and vim.bo[what].filetype or what --[[@as string]]
  local lang = vim.treesitter.language.get_lang(what)
  return lang ~= nil and M.get_installed()[lang] ~= nil
end

function M.foldexpr()
  return M.have() and vim.treesitter.foldexpr() or "0"
end

function M.indentexpr()
  return M.have() and require("nvim-treesitter").indentexpr() or -1
end

return {
  {
    "nvim-treesitter/nvim-treesitter-context", -- Show code context
    lazy = true,
    module = "treesitter-context",
    config = function(_, opts)
      ---@type pmsp.neovim.Config
      local config = require("config")
      local colors = config.theme.colors

      require("snacks")
      Set_hl({ ContextBottom = { underline = true, sp = colors.bg0_s } }, { prefix = "Treesitter", default = true })

      require("treesitter-context").setup(opts)
    end,
  },

  {
    "windwp/nvim-ts-autotag", -- Automatically add closing tags for HTML and JSX
    lazy = true,
    opts = {},
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    lazy = true,
    opts = {
      select = {
        lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      },
    },
    keys = function()
      local moves = {
        goto_next_start = { ["]m"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
        goto_next_end = { ["]M"] = "@function.outer", ["]C"] = "@class.outer", ["]A"] = "@parameter.inner" },
        goto_previous_start = { ["[m"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
        goto_previous_end = { ["[M"] = "@function.outer", ["[C"] = "@class.outer", ["[A"] = "@parameter.inner" },
      }
      ---@type LazyKeysSpec[]
      local ret = {
        -- select
        {
          "am",
          mode = { "n", "x", "o" },
          desc = "Outer function",
          function() require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects") end,
        },
        {
          "im",
          mode = { "n", "x", "o" },
          desc = "Inner function",
          function() require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects") end,
        },
        {
          "ac",
          mode = { "n", "x", "o" },
          desc = "Outer class",
          function() require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects") end,
        },
        {
          "ic",
          mode = { "n", "x", "o" },
          desc = "Inner class",
          function() require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects") end,
        },

        -- swap
        {
          "<leader>.",
          mode = { "n", "o" },
          desc = "Swap next inner parameter",
          function() require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner") end,
        },
        {
          "<leader>,",
          mode = { "n", "o" },
          desc = "Swap previous inner parameter",
          function() require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner") end,
        },
      }

      for method, keymaps in pairs(moves) do
        for key, query in pairs(keymaps) do
          local desc = query:gsub("@", ""):gsub("%..*", "")
          desc = desc:sub(1, 1):upper() .. desc:sub(2)
          desc = (key:sub(1, 1) == "[" and "Prev " or "Next ") .. desc
          desc = desc .. (key:sub(2, 2) == key:sub(2, 2):upper() and " End" or " Start")
          ret[#ret + 1] = {
            key,
            function()
              -- don't use treesitter if in diff mode and the key is one of the c/C keys
              if vim.wo.diff and key:find("[cC]") then return vim.cmd("normal! " .. key) end
              require("nvim-treesitter-textobjects.move")[method](query, "textobjects")
            end,
            desc = desc,
            mode = { "n", "x", "o" },
            silent = true,
          }
        end
      end
      return ret
    end,
    config = function(_, opts)
      local TS = require("nvim-treesitter-textobjects")
      if not TS.setup then
        Snacks.notify("Please use `:Lazy` and update `nvim-treesitter`")
        return
      end
      TS.setup(opts)
    end,
  },

  {
    "andymass/vim-matchup",
    lazy = true, -- we let treesitter manage this
    init = function()
      vim.g.matchup_matchparen_deferred = 1
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    version = false, -- last release is way too old and doesn't work on Windows
    branch = "main",
    build = function()
      local TS = require("nvim-treesitter")
      if not TS.get_installed then
        Snacks.notify("Please restart Neovim and run `:TSUpdate` to use the `nvim-treesitter` **main** branch.")
        return
      end

      TS.update(nil, { summary = true })
    end,
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
    dependencies = {
      "nvim-treesitter/nvim-treesitter-context", -- Show code context
      "windwp/nvim-ts-autotag", -- Automatically add closing tags for HTML and JSX
      "RRethy/nvim-treesitter-endwise", --- Wisely add 'end' in Ruby, Vimscript, Lua, etc.
      "nvim-treesitter/nvim-treesitter-textobjects",
      {
        "HiPhish/rainbow-delimiters.nvim", -- Rainbow delimiters for Neovim with Tree-sitter
        main = "rainbow-delimiters.setup",
        opts = function()
          return {
            strategy = {
              [""] = require("rainbow-delimiters").strategy["global"],
              vim = require("rainbow-delimiters").strategy["local"],
            },
            query = {
              [""] = "rainbow-delimiters",
              lua = "rainbow-blocks",
            },
            highlight = {
              "MiniIconsRed",
              "MiniIconsYellow",
              "MiniIconsBlue",
              "MiniIconsOrange",
              "MiniIconsGreen",
              "MiniIconsPurple",
              "MiniIconsCyan",
            },
          }
        end,
      },
    },
    cmd = { "TSUpdate", "TSUpdateSync", "TSInstall", "TSLog", "TSUninstall" },
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      { "<TAB>", desc = "Increment Selection" },
      { "<S-TAB>", desc = "Decrement Selection", mode = "x" },
    },
    opts = {
      ensure_installed = ensure_installed,
      highlight = { enable = true },
      indent = { enable = true },
    },
    config = function(_, opts)
      local TS = require("nvim-treesitter")

      TS.setup(opts)
      M.get_installed(true) -- initialize the installed langs

      -- install missing parsers
      local install = vim.tbl_filter(function(lang)
        return not M.have(lang)
      end, opts.ensure_installed or {})
      if #install > 0 then
        TS.install(install, { summary = true }):await(function()
          M.get_installed(true) -- refresh the installed langs
        end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("configure_treesitter", { clear = true }),
        callback = function(ev)
          if not M.have(ev.match) then
            return
          end

          -- highlighting
          if vim.tbl_get(opts, "highlight", "enable") ~= false then
            if vim.api.nvim_buf_line_count(0) <= 5000 then
              pcall(vim.treesitter.start)
            end
          end

          -- indents
          if vim.tbl_get(opts, "indent", "enable") ~= false and M.have(ev.match, "indents") then
            if vim.tbl_contains({ "eruby", "html", "python", "css", "rust" }, ev.match) == 0 then
              vim.api.nvim_set_option_value("indentexpr", "v:lua.M.indentexpr()", { scope = "local" })
            end
          end

          -- folds
          if vim.tbl_get(opts, "folds", "enable") ~= false and M.have(ev.match, "folds") then
            if vim.api.nvim_set_option_value("foldmethod", "expr", { scope = "local" }) then
              vim.api.nvim_set_option_value("foldexpr", "v:lua.M.foldexpr()", { scope = "local" })
            end
          end
        end,
      })
    end,
  },
}
