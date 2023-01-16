-- urlview.nvim (https://github.com/axieax/urlview.nvim)
-- 🔎 Neovim plugin for viewing all the URLs in a buffer

return {
  "axieax/urlview.nvim",
  config = function()
    require("urlview").setup({
      default_action = "system",
      jump = {
        prev = "[U",
        next = "]U",
      },
    })

    local function open_buffer_urlview()
      if vim.fn.expand("%:p") == vim.fn.stdpath("config") .. "/lua/packer_init.lua" then
        vim.cmd [[UrlView packer]]
      else
        vim.cmd [[UrlView]]
      end
    end

    local urlview_augroup = vim.api.nvim_create_augroup("urlview", { clear = true })

    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      pattern = "*",
      group = urlview_augroup,
      callback = function()
        local m = require("mapx").setup { global = "force", whichkey = true }
        local opts = { silent = true }

        m.nnoremap("<leader>fu", open_buffer_urlview, opts, "List buffer URLs", "buffer")
      end
    })
  end
}
