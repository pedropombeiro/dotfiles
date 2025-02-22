local function augroup(name) return vim.api.nvim_create_augroup("_" .. name, { clear = true }) end

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = {
    "PlenaryTestPopup",
    "help",
    "startuptime",
    "neotest-output",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    require("which-key").add( ---@type wk.Spec
      { "q", "<Cmd>close<CR>", buffer = event.buf, mode = { "n" }, silent = true, icon = "󰈆" }
    )
  end,
})

-- make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("man_unlisted"),
  pattern = { "man" },
  callback = function(event) vim.bo[event.buf].buflisted = false end,
})
