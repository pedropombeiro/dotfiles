-- git-messenger.vim (https://github.com/rhysd/git-messenger.vim)
--  Vim and Neovim plugin to reveal the commit messages under the cursor

vim.g.git_messenger_no_default_mappings = true

return {
  'rhysd/git-messenger.vim', -- Vim and Neovim plugin to reveal the commit messages under the cursor
  cmd = 'GitMessenger',
  keys = {
    { '<leader>gm', '<Plug>(git-messenger)', desc = 'Open commit message' },
  }
}
