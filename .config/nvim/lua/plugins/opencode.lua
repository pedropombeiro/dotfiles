-- opencode.nvim (https://github.com/NickvanDyke/opencode.nvim)
--  Integrate opencode AI assistant with Neovim

return {
  "NickvanDyke/opencode.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  lazy = true,
  cmd = "Opencode",
  keys = {
    { "<leader>ac", function() require("opencode").toggle() end, desc = "Toggle opencode terminal" },
    {
      "<leader>aa",
      function() require("opencode").ask("@this: ", { submit = false }) end,
      mode = { "n", "x" },
      desc = "Ask opencode…",
    },
    {
      "<leader>as",
      function() require("opencode").select() end,
      mode = { "n", "x" },
      desc = "Select opencode action…",
    },
    {
      "<leader>ap",
      function() require("opencode").prompt("review") end,
      mode = { "n", "x" },
      desc = "Review with opencode",
    },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {}
    vim.o.autoread = true

    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "*opencode*",
      callback = function()
        vim.keymap.set("t", "<Esc><Esc>", "<Esc><Esc>", { buffer = true, desc = "Send Esc to opencode" })
      end,
    })
  end,
  specs = {
    {
      "folke/which-key.nvim",
      opts = {
        ---@module "which-key"
        ---@type wk.Spec
        spec = {
          { "<leader>a", group = "AI (opencode)" },
        },
      },
      opts_extend = { "spec" },
    },
  },
}
