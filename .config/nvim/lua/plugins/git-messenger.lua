-- git-messenger.vim (https://github.com/rhysd/git-messenger.vim)
--  Vim and Neovim plugin to reveal the commit messages under the cursor

return {
  "rhysd/git-messenger.vim", -- Vim and Neovim plugin to reveal the commit messages under the cursor
  cmd = "GitMessenger",
  keys = "<leader>gm",
  init = function()
    local wk = require("which-key")

    wk.register({
      ["gm"] = { "Open commit message" }
    }, { prefix = "<leader>" })
  end
}
