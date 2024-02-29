-- gitsigns.nvim (https://github.com/lewis6991/gitsigns.nvim)
--  Git integration for buffers

local on_attach = function(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if vim.fn.expand('%:t') == 'lsp.log' or vim.bo.filetype == 'help' then
    return false
  end
  local size = vim.fn.getfsize(name)
  if size > 1024 * 1024 * 5 then
    return false
  end

  local gs = package.loaded.gitsigns
  local wk = require('which-key')

  -- Actions
  wk.register({
    h = {
      name = 'Gitsigns',
      s = { ':Gitsigns stage_hunk<CR>', 'Stage Git hunk', mode = { 'n', 'v' } },
      u = { gs.undo_stage_buffer, 'Undo stage Git hunk' },
      r = { ':Gitsigns reset_hunk<CR>', 'Reset Git hunk', mode = { 'n', 'v' } },
      p = { gs.preview_hunk_inline, 'Preview Git hunk' },
      S = { gs.stage_buffer, 'Stage buffer' },
      R = { gs.reset_buffer, 'Reset buffer' },
      b = {
        function()
          gs.blame_line({ full = true })
        end,
        'Git blame line',
      },
      d = { gs.diffthis, 'Git diff this' },
      D = {
        function()
          gs.diffthis('~')
        end,
        'Git diff this ~',
      },
    },
  }, { prefix = '<leader>', buffer = bufnr })

  wk.register({
    ['['] = {
      -- Navigation
      c = {
        function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(gs.prev_hunk)
          return '<Ignore>'
        end,
        'Previous Git hunk',
      },
      -- Options
      g = {
        name = 'Git',
        b = {
          function()
            gs.toggle_current_line_blame(true)
          end,
          'Enable current line blame',
        },
        d = {
          function()
            gs.toggle_deleted(true)
          end,
          'Enable Git-deleted',
        },
      },
    },
    [']'] = {
      -- Navigation
      c = {
        function()
          if vim.wo.diff then
            return ']c'
          end
          vim.schedule(gs.next_hunk)
          return '<Ignore>'
        end,
        'Next Git hunk',
      },
      -- Options
      g = {
        name = 'Git',
        b = {
          function()
            gs.toggle_current_line_blame(false)
          end,
          'Disable current line blame',
        },
        d = {
          function()
            gs.toggle_deleted(false)
          end,
          'Disable Git-deleted',
        },
      },
    },
  }, { buffer = bufnr, expr = true })

  -- Text object
  wk.register({
    i = {
      h = { ':<C-U>Gitsigns select_hunk<CR>', 'Select Git hunk' },
    },
  }, { mode = { 'o', 'x' }, buffer = bufnr })
end

return {
  'lewis6991/gitsigns.nvim',
  dependencies = 'nvim-lua/plenary.nvim',
  event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
  opts = {
    signs = {
      add = { text = '▌', show_count = true },
      change = { text = '▌', show_count = true },
      delete = { text = '▐', show_count = true },
      topdelete = { text = '▛', show_count = true },
      changedelete = { text = '▚', show_count = true },
      untracked = { text = '▎' },
    },
    update_debounce = 500,
    sign_priority = 10,
    numhl = false,
    signcolumn = true,
    current_line_blame = true,
    count_chars = {
      [1] = '',
      [2] = '₂',
      [3] = '₃',
      [4] = '₄',
      [5] = '₅',
      [6] = '₆',
      [7] = '₇',
      [8] = '₈',
      [9] = '₉',
      ['+'] = '₊',
    },
    diff_opts = {
      internal = true,
      algorithm = 'patience',
      indent_heuristic = true,
      linematch = 60,
    },
    on_attach = on_attach,
    preview_config = {
      -- Options passed to nvim_open_win
      border = require('config').ui.border,
      style = 'minimal',
      relative = 'cursor',
      row = 0,
      col = 1,
    },
    yadm = {
      enable = true,
    },
  },
  config = function(_, opts)
    require('gitsigns').setup(opts)

    require('scrollbar.handlers.gitsigns').setup()

    -- Compare with the default branch
    local branch = string.match(vim.fn.system('git branch -rl "*/HEAD"'), '.*/(.*)\n')
    if branch then
      require('gitsigns').change_base(branch, true)
    end
  end,
}
