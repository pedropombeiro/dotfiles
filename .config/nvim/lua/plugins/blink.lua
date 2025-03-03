-- blink.nvim (https://github.com/saghen/blink.cmp)
--  Performant, batteries-included completion plugin for Neovim.

local function is_qnap()
  if vim.fn.has("unix") == 1 then -- Check if it's a Unix-like system (Linux, macOS, etc.)
    local uname_output = vim.fn.system("uname -a")
    return uname_output and string.find(string.lower(uname_output), "qnap") ~= nil
  end

  return false
end

return {
  -- auto completion
  {
    "saghen/blink.cmp",

    -- use a release tag to download pre-built binaries
    version = "*",

    -- optional: provides snippets for the snippet source
    dependencies = {
      "rafamadriz/friendly-snippets",
      "bydlw98/blink-cmp-env",
      "disrupted/blink-cmp-conventional-commits",
      "mikavilpas/blink-ripgrep.nvim",
    },

    event = { "InsertEnter", "CmdLineEnter" },

    cond = function()
      if is_qnap() then
        local libpath = vim.fn.stdpath("data") .. "/lazy/blink.cmp/target/release/libblink_cmp_fuzzy.so"

        return vim.fn.filereadable(libpath) == 1
      end

      return true
    end,
    ---@module "blink.cmp"
    ---@diagnostic disable-next-line: undefined-doc-name
    ---@type function|blink.cmp.Config
    opts = function()
      return {
        -- 'default' for mappings similar to built-in completion
        -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
        -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
        -- See the full "keymap" documentation for information on defining your own keymap.
        keymap = {
          preset = "super-tab",

          ["<C-y>"] = { "show", "show_documentation", "hide_documentation" },
        },

        appearance = {
          -- Sets the fallback highlight groups to nvim-cmp's highlight groups
          -- Useful for when your theme doesn't support blink.cmp
          -- Will be removed in a future release
          use_nvim_cmp_as_default = true,
          -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
          -- Adjusts spacing to ensure icons are aligned
          nerd_font_variant = "mono",
        },

        completion = {
          documentation = {
            auto_show = true,
            auto_show_delay_ms = 500,
            window = {
              border = require("config").ui.border,
            },
          },
          ghost_text = { enabled = true },
          menu = {
            auto_show = function(ctx) return ctx.mode == "cmdline" end,
            draw = {
              components = {
                kind_icon = {
                  ellipsis = false,
                  text = function(ctx) return require("config").ui.icons.kinds[ctx.kind] end,
                },
              },
              treesitter = { "lsp" },
            },
          },
        },

        fuzzy = {
          prebuilt_binaries = {
            -- In QNAP, we don't want to download the prebuilt binaries, since they are built with a version of glibc that is too recent
            -- To build a supported version, do the following:
            -- docker run -it --name rust_builder ubuntu:14.04
            -- apt update -y && apt install -y curl git gcc && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh && . "$HOME/.cargo/env" && git clone https://github.com/Saghen/blink.cmp.git && cd blink.cmp/ && cargo build --release
            -- From the QNAP host, run:
            --   docker cp rust_builder:/blink.cmp/target/release/libblink_cmp_fuzzy.so $HOME/.local/share/nvim/lazy/blink.cmp/target/release/libblink_cmp_fuzzy.so
            -- docker rm rust_builder
            download = not is_qnap(),
          },
        },

        signature = { enabled = false },

        -- Default list of enabled providers defined so that you can extend it
        -- elsewhere in your config, without redefining it, due to `opts_extend`
        sources = {
          default = { "lazydev", "conventional_commits", "lsp", "path", "snippets", "buffer", "ripgrep", "env" },
          providers = {
            lazydev = {
              name = "LazyDev",
              module = "lazydev.integrations.blink",
              -- make lazydev completions top priority (see `:h blink.cmp`)
              score_offset = 100,
            },
            conventional_commits = {
              name = "Conventional Commits",
              module = "blink-cmp-conventional-commits",
              enabled = function() return vim.bo.filetype == "gitcommit" end,
              ---@module "blink-cmp-conventional-commits"
              ---@type blink-cmp-conventional-commits.Options
              opts = {}, -- none so far
            },
            ripgrep = {
              module = "blink-ripgrep",
              name = "Ripgrep",
              -- the options below are optional
              ---@module "blink-ripgrep"
              ---@type blink-ripgrep.Options
              opts = {
                project_root_marker = { ".git", "lazy-lock.json" },
                ignore_paths = { "node_modules", "vendor", "tmp", "bin" },
                -- Features that are not yet stable and might change in the future.
                -- You can enable these to try them out beforehand, but be aware
                -- that they might change. Nothing is enabled by default.
                future_features = {
                  -- The backend to use for searching. Defaults to "ripgrep".
                  -- "gitgrep" is available as a preview right now.
                  backend = { use = "ripgrep" },
                },
              },
            },
            env = {
              name = "Env",
              module = "blink-cmp-env",
              --- @module "blink-cmp-env"
              --- @type blink-cmp-env.Options
              opts = {
                item_kind = require("blink.cmp.types").CompletionItemKind.Variable,
                show_braces = true,
                show_documentation_window = true,
              },
            },
          },
        },
      }
    end,
    -- allows extending the providers array elsewhere in your config
    -- without having to redefine it
    opts_extend = { "sources.default" },
    config = function(_, opts)
      Set_hl({ GhostText = { link = "LspInlayHint" } }, { prefix = "BlinkCmp", default = true })

      require("blink-cmp").setup(opts)
    end,
  },
}
