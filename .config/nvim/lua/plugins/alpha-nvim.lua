-- α alpha-nvim (https://github.com/goolord/alpha-nvim)
--  a lua powered greeter like vim-startify / dashboard-nvim

return {
  "goolord/alpha-nvim",
  dependencies = "kyazdani42/nvim-web-devicons",
  event = "VimEnter",
  config = function()
    require "alpha".setup(require "alpha.themes.theta".config)
  end
}
