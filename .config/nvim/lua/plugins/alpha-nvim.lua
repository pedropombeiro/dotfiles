-- α alpha-nvim (https://github.com/goolord/alpha-nvim)
--  a lua powered greeter like vim-startify / dashboard-nvim

return {
  "goolord/alpha-nvim",
  dependencies = "kyazdani42/nvim-web-devicons",
  event = "VimEnter",
  config = function()
    -- originally authored by @AdamWhittingham
    local path_ok, plenary_path = pcall(require, "plenary.path")
    if not path_ok then
      return
    end

    local dashboard = require("alpha.themes.dashboard")
    local cdir = vim.fn.getcwd()
    local if_nil = vim.F.if_nil

    local nvim_web_devicons = {
      enabled = true,
      highlight = true,
    }

    local function get_extension(fn)
      local match = fn:match("^.+(%..+)$")
      local ext = ""
      if match ~= nil then
        ext = match:sub(2)
      end
      return ext
    end

    local function icon(fn)
      local nwd = require("nvim-web-devicons")
      local ext = get_extension(fn)
      return nwd.get_icon(fn, ext, { default = true })
    end

    local function file_button(fn, sc, short_fn, autocd)
      short_fn = short_fn or fn
      local ico_txt
      local fb_hl = {}

      if nvim_web_devicons.enabled then
        local ico, hl = icon(fn)
        local hl_option_type = type(nvim_web_devicons.highlight)
        if hl_option_type == "boolean" then
          if hl and nvim_web_devicons.highlight then
            table.insert(fb_hl, { hl, 0, 3 })
          end
        end
        if hl_option_type == "string" then
          table.insert(fb_hl, { nvim_web_devicons.highlight, 0, 3 })
        end
        ico_txt = ico .. "  "
      else
        ico_txt = ""
      end
      local cd_cmd = (autocd and " | cd %:p:h" or "")
      local file_button_el = dashboard.button(sc, ico_txt .. short_fn, "<cmd>e " .. fn .. cd_cmd .. " <CR>")
      local fn_start = short_fn:match(".*[/\\]")
      if fn_start ~= nil then
        table.insert(fb_hl, { "Comment", #ico_txt - 2, #fn_start + #ico_txt })
      end
      file_button_el.opts.hl = fb_hl
      return file_button_el
    end

    local default_mru_ignore = { "gitcommit" }

    local mru_opts = {
      ignore = function(path, ext)
        return (string.find(path, "COMMIT_EDITMSG")) or (vim.tbl_contains(default_mru_ignore, ext))
      end,
      autocd = false
    }

    --- @param start number
    --- @param cwd string? optional
    --- @param items_number number? optional number of items to generate, default = 10
    local function mru(start, cwd, items_number, opts)
      opts = opts or mru_opts
      items_number = if_nil(items_number, 10)

      local oldfiles = {}
      for _, v in pairs(vim.v.oldfiles) do
        if #oldfiles == items_number then
          break
        end
        local cwd_cond
        if not cwd then
          cwd_cond = true
        else
          cwd_cond = vim.startswith(v, cwd)
        end
        local ignore = (opts.ignore and opts.ignore(v, get_extension(v))) or false
        if (vim.fn.filereadable(v) == 1) and cwd_cond and not ignore then
          oldfiles[#oldfiles + 1] = v
        end
      end
      local target_width = 35

      local tbl = {}
      for i, fn in ipairs(oldfiles) do
        local short_fn
        if cwd then
          short_fn = vim.fn.fnamemodify(fn, ":.")
        else
          short_fn = vim.fn.fnamemodify(fn, ":~")
        end

        if #short_fn > target_width then
          short_fn = plenary_path.new(short_fn):shorten(1, { -2, -1 })
          if #short_fn > target_width then
            short_fn = plenary_path.new(short_fn):shorten(1, { -1 })
          end
        end

        local shortcut = tostring(i + start - 1)

        local file_button_el = file_button(fn:gsub("#", '\\#'), shortcut, short_fn, opts.autocd)
        tbl[i] = file_button_el
      end
      return {
        type = "group",
        val = tbl,
        opts = {},
      }
    end

    local version = vim.version()
    local header = {
      type = "text",
      val = {
        [[                               __     ]] ..
            version.major .. "." .. version.minor .. "." .. version.patch .. [[      ]],
        [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
        [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
        [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
      },
      opts = {
        position = "center",
        hl = "Type",
        -- wrap = "overflow";
      },
    }

    local section_mru = {
      type = "group",
      val = {
        {
          type = "text",
          val = "Recent files",
          opts = {
            hl = "SpecialComment",
            shrink_margin = false,
            position = "center",
          },
        },
        { type = "padding", val = 1 },
        {
          type = "group",
          val = function()
            return { mru(0, cdir) }
          end,
          opts = { shrink_margin = false },
        },
      },
    }

    local buttons = {
      type = "group",
      val = {
        { type = "text", val = "Quick links", opts = { hl = "SpecialComment", position = "center" } },
        { type = "padding", val = 1 },
        dashboard.button("e", "  New file", "<cmd>ene<CR>"),
        dashboard.button("b", "  Open branch files", "<cmd>Branch<CR>"),
        dashboard.button("SPC f f", "  Find file"),
        dashboard.button("SPC f h", "  History"),
        dashboard.button("SPC f r", "  Live grep"),
        dashboard.button("c", "  Configuration", "<cmd>cd ~ | e $MYVIMRC | NvimTreeFindFileToggle<CR>"),
        dashboard.button("l", "  Plugin manager", "<cmd>Lazy!<CR>"),
        dashboard.button("q", "  Quit", "<cmd>qa<CR>"),
      },
      position = "center",
    }

    local config = {
      layout = {
        { type = "padding", val = 2 },
        header,
        { type = "padding", val = 2 },
        section_mru,
        { type = "padding", val = 2 },
        buttons,
      },
      opts = {
        margin = 5,
        setup = function()
          vim.api.nvim_create_autocmd("DirChanged", {
            pattern = "*",
            callback = function() require("alpha").redraw() end,
          })
        end,
      },
    }

    local opts = {
      header = header,
      buttons = buttons,
      mru = mru,
      mru_opts = mru_opts,
      config = config,
      nvim_web_devicons = nvim_web_devicons,
    }

    require("alpha").setup(opts.config)
  end
}
