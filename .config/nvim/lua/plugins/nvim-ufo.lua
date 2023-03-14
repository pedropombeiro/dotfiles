-- nvim-ufo.lua (https://github.com/kevinhwang91/nvim-ufo)
--  Not UFO in the sky, but an ultra fold in Neovim.

local function setFoldOptions()
  if vim.fn.has("nvim-0.9") == 1 then
    vim.opt.foldcolumn = "1"
  else
    vim.opt.foldcolumn = "0"
  end
  vim.opt.foldlevel      = 99
  vim.opt.foldlevelstart = 99
  vim.opt.foldenable     = true
  vim.opt.fillchars      = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
end

local function fold_virt_text_handler(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local suffix = ("  %d "):format(endLnum - lnum)
  local sufWidth = vim.fn.strdisplaywidth(suffix)
  local targetWidth = width - sufWidth
  local curWidth = 0
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      local hlGroup = chunk[2]
      table.insert(newVirtText, { chunkText, hlGroup })
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      -- str width returned from truncate() may less than 2nd argument, need padding
      if curWidth + chunkWidth < targetWidth then
        suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
      end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  table.insert(newVirtText, { suffix, "MoreMsg" })
  return newVirtText
end

return {
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async",
    "neovim/nvim-lspconfig",
  },
  event = "BufRead",
  ft = {
    "bash",
    "go",
    "json",
    "lua",
    "markdown",
    "ruby",
    "yaml",
  },
  keys = {
    { "zR", function() require("ufo").openAllFolds() end,  mode = { "n", "v" }, desc = "Open All Folds", },
    { "zM", function() require("ufo").closeAllFolds() end, mode = { "n", "v" }, desc = "Close All Folds", },
    {
      "K",
      function()
        local winid = require("ufo").peekFoldedLinesUnderCursor()
        if not winid then
          vim.lsp.buf.hover()
        end
      end,
      mode = { "n", "v" }
    }
  },
  opts = function()
    setFoldOptions()

    --- Override foldcolumn colors to match theme
    local config = require("config")
    local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
    ---@diagnostic disable: undefined-field
    if theme == config.theme.name then
      local function set_hl(name, attr)
        vim.api.nvim_set_hl(0, name, attr)
      end

      set_hl("FoldColumn", { ctermbg = "none", bg = "none", ctermfg = "gray", fg = config.theme.colors.gray })
      ---@diagnostic enable: undefined-field
    end

    return {
      close_fold_kinds       = { "imports" },
      fold_virt_text_handler = fold_virt_text_handler,
      provider_selector      = function(bufnr, filetype, buftype)
        return { "treesitter", "indent" }
      end
    }
  end,
}
