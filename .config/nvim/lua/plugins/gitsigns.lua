-- gitsigns.nvim (https://github.com/lewis6991/gitsigns.nvim)
--  Git integration for buffers

local on_attach = function(bufnr)
  local gs = package.loaded.gitsigns
  local m = require('mapx')

  local function nmap(l, r, desc, opts)
    opts = opts or {}
    opts.buffer = bufnr
    m.nmap(l, r, desc, opts)
  end

  local function vmap(l, r, desc, opts)
    opts = opts or {}
    opts.buffer = bufnr
    m.vmap(l, r, desc, opts)
  end

  local function omap(l, r, desc, opts)
    opts = opts or {}
    opts.buffer = bufnr
    m.omap(l, r, desc, opts)
  end

  local function xmap(l, r, desc, opts)
    opts = opts or {}
    opts.buffer = bufnr
    m.xmap(l, r, desc, opts)
  end

  -- Navigation
  nmap(']c', function()
    if vim.wo.diff then return ']c' end
    vim.schedule(gs.next_hunk)
    return '<Ignore>'
  end, 'Next Git hunk', { expr = true })

  nmap('[c', function()
    if vim.wo.diff then return '[c' end
    vim.schedule(gs.prev_hunk)
    return '<Ignore>'
  end, 'Previous Git hunk', { expr = true })

  -- Actions
  m.nname('<leader>h', 'Git hunk')
  m.vname('<leader>h', 'Git hunk')
  nmap('<leader>hs', ':Gitsigns stage_hunk<CR>', 'Stage Git hunk')
  vmap('<leader>hs', ':Gitsigns stage_hunk<CR>', 'Stage Git hunk')
  nmap('<leader>hr', ':Gitsigns reset_hunk<CR>', 'Reset Git hunk')
  vmap('<leader>hr', ':Gitsigns reset_hunk<CR>', 'Reset Git hunk')
  nmap('<leader>hS', gs.stage_buffer, 'Stage buffer')
  nmap('<leader>hu', gs.undo_stage_hunk, 'Undo stage Git hunk')
  nmap('<leader>hR', gs.reset_buffer, 'Reset buffer from Git')
  nmap('<leader>hp', gs.preview_hunk, 'Preview Git hunk')
  nmap('<leader>hb', function() gs.blame_line { full = true } end, 'Git blame line')
  nmap('<leader>tb', gs.toggle_current_line_blame, 'Toggle current line blame')
  nmap('<leader>hd', gs.diffthis, 'Git diff this')
  nmap('<leader>hD', function() gs.diffthis('~') end, 'Git diff this ~')
  nmap('<leader>td', gs.toggle_deleted, 'Toggle Git-deleted')

  -- Text object
  omap('ih', ':<C-U>Gitsigns select_hunk<CR>', 'Select Git hunk')
  xmap('ih', ':<C-U>Gitsigns select_hunk<CR>', 'Select Git hunk')
end

return {
  'lewis6991/gitsigns.nvim',
  dependencies = 'nvim-lua/plenary.nvim',
  event = 'BufReadPre',
  opts = {
    signs = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '契' },
      topdelete = { text = '契' },
      changedelete = { text = '▎' },
      untracked = { text = '▎' },
    },
    on_attach = on_attach,
    yadm = {
      enable = true,
    }
  },
  config = function(_, opts)
    require('gitsigns').setup(opts)

    require('scrollbar.handlers.gitsigns').setup()
  end
}
