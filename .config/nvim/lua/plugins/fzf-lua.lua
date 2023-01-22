-- fzf-lua (https://github.com/ibhagwan/fzf-lua)
--  Improved fzf.vim written in lua

---@format disable-next
local keys = {
  -- File operations
  { "<leader>ff",    "<Cmd>FzfLua files<CR>",            desc = "Files" },
  { "<leader>fr",    "<Cmd>FzfLua live_grep_native<CR>", desc = "Live grep (rg)" },
  { "<leader>fF",    "<Cmd>FzfLua resume<CR>",           desc = "Resume last FZF command/query" },
  { "<leader><Tab>", "<Cmd>FzfLua keymaps<CR>",          desc = "Keymaps" },
  { "<leader>fb",    "<Cmd>FzfLua buffers<CR>",          desc = "Buffers" },
  { "<leader>fc",    "<Cmd>FzfLua colorschemes<CR>",     desc = "Colorschemes" },
  { "<leader>fK",    "<Cmd>FzfLua man_pages<CR>",        desc = "Man pages" },
  { "<leader>fl",    "<Cmd>FzfLua loclist<CR>",          desc = "Location list" },
  { "<leader>fq",    "<Cmd>FzfLua quickfix<CR>",         desc = "Quickfix list" },
  { "<leader>ft",    "<Cmd>FzfLua tabs<CR>",             desc = "Tabs" },
  { "<leader>fT",    "<Cmd>FzfLua filetypes<CR>",        desc = "Filetypes" },
  { "<leader>fh",    "<Cmd>FzfLua oldfiles<CR>",         desc = "Old files" },
  { "<leader>f:",    "<Cmd>FzfLua command_history<CR>",  desc = "Command history" },
  { "<leader>f/",    "<Cmd>FzfLua search_history<CR>",   desc = "Search history" },
  { "<leader>f`",    "<Cmd>FzfLua marks<CR>",            desc = "Marks" },
  { "<leader>f'",    "<Cmd>FzfLua marks<CR>",            desc = "Marks" },
  { "<leader>f.",    "<Cmd>FzfLua jumps<CR>",            desc = "Jump list" },
  { "<leader>f@",    "<Cmd>FzfLua registers<CR>",        desc = "Registers" },
  { "<leader>fs",    "<Cmd>FzfLua spell_suggest<CR>",    desc = "Spelling suggestions" },

  -- Git operations
  { "<leader>fgb",   "<Cmd>FzfLua git_branches<CR>",     desc = "Git branches" },
  { "<leader>fgc",   "<Cmd>FzfLua git_commits<CR>",      desc = "Git commits" },
  { "<leader>fgC",   "<Cmd>FzfLua git_bcommits<CR>",     desc = "Git commits (buffer)" },
  {
    "<leader>fgg",
    function()
      require("fzf-lua").live_grep({ prompt = "GitGrep❯ ", cmd = "git grep --line-number --column --color=always" })
    end,
    desc = "Git grep"
  },
  { "<leader>fgf", "<Cmd>FzfLua git_files<CR>",                  desc = "Git files" },
  { "<leader>fgs", "<Cmd>FzfLua git_status<CR>",                 desc = "Git status" },
  { "<leader>fgS", "<Cmd>FzfLua git_stash<CR>",                  desc = "Git stash" },

  -- LSP operations
  { "<leader>ls",  "<Cmd>FzfLua lsp_document_symbols<CR>",       desc = "Document symbols" },
  { "<leader>lr",  "<Cmd>FzfLua lsp_references<CR>",             desc = "References" },
  { "<leader>ld",  "<Cmd>FzfLua lsp_definitions<CR>",            desc = "Definitions" },
  { "<C-]>",       "<Cmd>FzfLua lsp_definitions<CR>",            desc = "Definitions" },
  { "<leader>lt",  "<Cmd>FzfLua lsp_typedefs<CR>",               desc = "Typedefs" },
  { "<leader>lws", "<Cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "Workspace symbols" },
  { "<leader>lca", "<Cmd>FzfLua lsp_code_actions<CR>",           desc = "Code actions" },
}

return {
  "ibhagwan/fzf-lua",
  dependencies = "junegunn/fzf", -- 🌸 A command-line fuzzy finder
  cmd = "FzfLua",
  keys = keys,
  init = function()
    local m = require("mapx")

    m.nname("<leader>f", "FZF")
    m.nname("<leader>fg", "FZF (Git)")
    m.nname("<leader>l", "FZF (LSP)")
    m.nname("<leader>lc", "FZF (LSP code actions)")
  end,
  config = function()
    require("fzf-lua").setup({
      winopts = {
        preview = {
          layout = "vertical",
        },
      },
    })

    require("fzf-lua").register_ui_select() -- register fzf-lua as the UI interface for vim.ui.select
  end
}
