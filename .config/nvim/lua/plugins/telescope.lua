-- Telescope (https://github.com/nvim-telescope/telescope.nvim)
--  Find, Filter, Preview, Pick. All lua, all the time.

---@format disable-next
local keys = {
  -- File operations
  { "<leader>ff",    "<Cmd>Telescope find_files<CR>",       desc = "Files" },
  { "<leader>fr",    "<Cmd>Telescope live_grep<CR>",        desc = "Live grep (rg)" },
  { "<leader>fF",    "<Cmd>Telescope resume<CR>",           desc = "Resume last Telescope command/query" },
  { "<leader><Tab>", "<Cmd>Telescope keymaps<CR>",          desc = "Keymaps" },
  { "<leader>fb",    "<Cmd>Telescope buffers<CR>",          desc = "Buffers" },
  { "<leader>fc",    "<Cmd>Telescope colorscheme<CR>",      desc = "Colorschemes" },
  { "<leader>fK",    "<Cmd>Telescope man_pages<CR>",        desc = "Man pages" },
  { "<leader>fl",    "<Cmd>Telescope loclist<CR>",          desc = "Location list" },
  { "<leader>fq",    "<Cmd>Telescope quickfix<CR>",         desc = "Quickfix list" },
  -- { "<leader>ft",    "<Cmd>FzfLua tabs<CR>",             desc = "Tabs" },
  { "<leader>fT",    "<Cmd>Telescope filetypes<CR>",        desc = "Filetypes" },
  { "<leader>fh",    "<Cmd>Telescope oldfiles<CR>",         desc = "Old files" },
  { "<leader>f:",    "<Cmd>Telescope command_history<CR>",  desc = "Command history" },
  { "<leader>f/",    "<Cmd>Telescope search_history<CR>",   desc = "Search history" },
  { "<leader>f`",    "<Cmd>Telescope marks<CR>",            desc = "Marks" },
  { "<leader>f'",    "<Cmd>Telescope marks<CR>",            desc = "Marks" },
  { "<leader>f.",    "<Cmd>Telescope jumplist<CR>",         desc = "Jump list" },
  { "<leader>f@",    "<Cmd>Telescope registers<CR>",        desc = "Registers" },
  { "<leader>fs",    "<Cmd>Telescope spell_suggest<CR>",    desc = "Spelling suggestions" },
  { "<leader>fp",    "<Cmd>Telescope lazy<CR>",             desc = "Plugins" },

  -- Git operations
  { "<leader>fgb",   "<Cmd>Telescope git_branches<CR>",     desc = "Git branches" },
  { "<leader>fgc",   "<Cmd>Telescope git_commits<CR>",      desc = "Git commits" },
  { "<leader>fgC",   "<Cmd>Telescope git_bcommits<CR>",     desc = "Git commits (buffer)" },
  {
    "<leader>fgg",
    function()
      local actions = require "telescope.actions"
      local action_state = require "telescope.actions.state"

      local function run_selection(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd([[!git grep --line-number --column --color=always ]] .. selection[1])
        end)
        return true
      end

      -- example for running a command on a file
      local opts = {
        attach_mappings = run_selection
      }
      require("telescope.builtin").find_files(opts)
    end,
    desc = "Git grep"
  },
  { "<leader>fgf", "<Cmd>Telescope git_files<CR>",                  desc = "Git files" },
  { "<leader>fgs", "<Cmd>Telescope git_status<CR>",                 desc = "Git status" },
  { "<leader>fgS", "<Cmd>Telescope git_stash<CR>",                  desc = "Git stash" },

  -- LSP operations
  { "<leader>ls",  "<Cmd>Telescope lsp_document_symbols<CR>",       desc = "Document symbols" },
  { "<leader>lr",  "<Cmd>Telescope lsp_references<CR>",             desc = "References" },
  { "<leader>ld",  "<Cmd>Telescope lsp_definitions<CR>",            desc = "Definitions" },
  { "<C-]>",       "<Cmd>Telescope lsp_definitions<CR>",            desc = "Definitions" },
  { "<leader>lt",  "<Cmd>Telescope lsp_type_definitions<CR>",               desc = "Typedefs" },
  { "<leader>lws", "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace symbols" },
  -- { "<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>",           desc = "Code actions" },
}

return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    { "nvim-lua/plenary.nvim" },
    { "nvim-telescope/telescope-ui-select.nvim" },
    { "tsakirist/telescope-lazy.nvim" }
  },
  keys = keys,
  init = function()
    local m = require("mapx")

    m.nname("<leader>f", "Telescope")
    m.nname("<leader>fg", "Telescope (Git)")
    m.nname("<leader>l", "Telescope (LSP)")
    m.nname("<leader>lc", "Telescope (LSP code actions)")
  end,
  config = function()
    require("telescope").setup({
      defaults = {
        layout_config = {
          vertical = { width = 0.5 }
        },
      },
      extensions = {
        ["ui-select"] = {
          -- require("telescope.themes").get_dropdown {
          -- even more opts
          -- }
        }
      }
    })

    require("telescope").load_extension "ui-select"
    require("telescope").load_extension "lazy"
  end
}
