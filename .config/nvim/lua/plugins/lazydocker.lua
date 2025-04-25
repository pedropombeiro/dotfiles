-- lazydocker.lua (https://github.com/crnvl96/lazydocker.nvim)
--  Plugin to open LazyDocker without quiting neovim.

return {
  "crnvl96/lazydocker.nvim",
  lazy = true,
  dependencies = { "MunifTanjim/nui.nvim" },
  ---@module "which-key"
  ---@type wk.Spec
  keys = {
    {
      "<leader>td",
      function()
        if vim.api.nvim_buf_get_name(0) ~= "" then -- Check if there's at least one buffer
          vim.api.nvim_exec2("cd %:h", { output = false }) -- switch to current directory so that Lazydocker filters containers from current stack
        end

        require("lazydocker").toggle()
      end,
      desc = "Open LazyDocker",
    },
  },
  opts = {},
}
