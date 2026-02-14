-- nvim-ufo (https://github.com/kevinhwang91/nvim-ufo)
--  Not UFO in the sky, but an ultra fold in Neovim.

local function setFoldOptions()
  ---@type pmsp.neovim.Config
  local config = require("config")
  local expander_icons = config.ui.icons.expander

  vim.opt.foldcolumn = "1"
  vim.opt.foldlevel = 99
  vim.opt.foldlevelstart = 99
  vim.opt.foldenable = true
  vim.opt.fillchars = [[eob: ,fold: ,foldopen:]]
    .. expander_icons.expanded
    .. [[,foldsep: ,foldclose:]]
    .. expander_icons.collapsed
end

local function fold_virt_text_handler(virtText, lnum, endLnum, width, truncate)
  local newVirtText = {}
  local totalLines = vim.api.nvim_buf_line_count(0)
  local foldedLines = endLnum - lnum
  local suffix = (" ↙ %d %d%%"):format(foldedLines, foldedLines / totalLines * 100)
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
      if curWidth + chunkWidth < targetWidth then suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth) end
      break
    end
    curWidth = curWidth + chunkWidth
  end
  local rAlignAppndx = math.max(math.min(vim.opt.textwidth["_value"], width - 1) - curWidth - sufWidth, 0)
  suffix = (" "):rep(rAlignAppndx) .. suffix
  table.insert(newVirtText, { suffix, "MoreMsg" })
  return newVirtText
end

return {
  {
    "kevinhwang91/nvim-ufo",
    ft = {
      "bash",
      "css",
      "eruby",
      "go",
      "html",
      "javascript",
      "json",
      "lua",
      "markdown",
      "ruby",
      "sh",
      "toml",
      "typescript",
      "yaml",
    },
    -- stylua: ignore
    ---@module "lazy"
    ---@type LazyKeysSpec[]
    keys = {
      { "zr", function() require("ufo").openFoldsExceptKinds() end,  mode = { "n", "v" }, desc = "Open folds except defined kinds", },
      { "zm", function() require("ufo").closeFoldsWith() end,  mode = { "n", "v" }, desc = "Close the folds > 0", },
      { "zR", function() require("ufo").openAllFolds() end,  mode = { "n", "v" }, desc = "Open all folds but keep foldlevel", },
      { "zM", function() require("ufo").closeAllFolds() end, mode = { "n", "v" }, desc = "Close all folds but keep foldlevel", },
      {
        "<leader>k",
        function()
          local winid = require("ufo").peekFoldedLinesUnderCursor()
          if not winid then
            vim.lsp.buf.hover()
          end
        end,
        desc = "Peek folded lines",
        mode = { "n", "v" },
      },
    },
    opts = {
      close_fold_kinds_for_ft = { go = { "imports" } },
      fold_virt_text_handler = fold_virt_text_handler,
      provider_selector = function() return { "treesitter", "indent" } end,
    },
    config = function(_, opts)
      setFoldOptions()

      --- Override foldcolumn colors to match theme
      ---@type pmsp.neovim.Config
      local config = require("config")
      local theme = vim.env.NVIM_THEME -- defined in ~/.shellrc/rc.d/_theme.sh
      if theme == config.theme.name then
        Set_hl(
          { FoldColumn = { ctermbg = "none", bg = "none", ctermfg = "gray", fg = config.theme.colors.gray } },
          { default = true }
        )
      end

      require("ufo").setup(opts)
    end,
  },
  { "kevinhwang91/promise-async", lazy = true },
}
