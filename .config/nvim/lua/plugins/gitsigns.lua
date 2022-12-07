-- gitsigns.nvim (https://github.com/lewis6991/gitsigns.nvim)
--  Git integration for buffers

require("gitsigns").setup({
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local m = require("mapx").setup { global = "force", whichkey = true }

    -- Navigation
    m.nmap("]c", function()
      if vim.wo.diff then return "]c" end
      vim.schedule(function() gs.next_hunk() end)
      return "<Ignore>"
    end, "Next Git hunk", { expr = true, buffer = bufnr })

    m.nmap("[c", function()
      if vim.wo.diff then return "[c" end
      vim.schedule(function() gs.prev_hunk() end)
      return "<Ignore>"
    end, "Previous Git hunk", { expr = true, buffer = bufnr })

    -- Actions
    m.nname("<leader>h", "Git hunk")
    m.vname("<leader>h", "Git hunk")
    m.nmap("<leader>hs", ":Gitsigns stage_hunk<CR>", "Stage Git hunk")
    m.vmap("<leader>hs", ":Gitsigns stage_hunk<CR>", "Stage Git hunk")
    m.nmap("<leader>hr", ":Gitsigns reset_hunk<CR>", "Reset Git hunk")
    m.vmap("<leader>hr", ":Gitsigns reset_hunk<CR>", "Reset Git hunk")
    m.nmap("<leader>hS", gs.stage_buffer, "Stage buffer")
    m.nmap("<leader>hu", gs.undo_stage_hunk, "Undo stage Git hunk")
    m.nmap("<leader>hR", gs.reset_buffer, "Reset buffer from Git")
    m.nmap("<leader>hp", gs.preview_hunk, "Preview Git hunk")
    m.nmap("<leader>hb", function() gs.blame_line { full = true } end, "Git blame line")
    m.nmap("<leader>tb", gs.toggle_current_line_blame, "Toggle current line blame")
    m.nmap("<leader>hd", gs.diffthis, "Git diff this")
    m.nmap("<leader>hD", function() gs.diffthis("~") end, "Git diff this ~")
    m.nmap("<leader>td", gs.toggle_deleted, "Toggle Git-deleted")

    -- Text object
    m.omap("ih", ":<C-U>Gitsigns select_hunk<CR>", "Select Git hunk")
    m.xmap("ih", ":<C-U>Gitsigns select_hunk<CR>", "Select Git hunk")
  end
})

require("scrollbar.handlers.gitsigns").setup()
