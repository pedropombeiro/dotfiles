-- vim-easy-align (https://github.com/junegunn/vim-easy-align)

local opts = { noremap = true, silent = true }

-- Start interactive EasyAlign in visual mode (e.g. vipga) and for a motion/text object (e.g. gaip)
vim.keymap.set({ "n", "x" }, "ga", "<Plug>(EasyAlign)", opts)
