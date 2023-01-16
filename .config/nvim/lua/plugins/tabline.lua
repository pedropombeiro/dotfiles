-- tabline.nvim (https://github.com/kdheepak/tabline.nvim)
--  A "buffer and tab" tabline for neovim

return {
  "kdheepak/tabline.nvim",
  cond = function()
    return not vim.g.started_by_firenvim
  end,
  dependencies = {
    "nvim-lualine/lualine.nvim", -- A blazing fast and easy to configure neovim statusline plugin written in pure lua.
    "kyazdani42/nvim-web-devicons"
  },
  config = function()
    require "tabline".setup {}

    vim.opt.sessionoptions:append { "tabpages", "globals" } -- store tabpages and globals in session
  end
}
