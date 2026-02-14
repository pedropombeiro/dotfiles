-- vim-fugitive (https://github.com/tpope/vim-fugitive)
--  A Git wrapper so awesome, it should be illegal

return {
  "tpope/vim-fugitive",
  cmd = {
    "Git",
    "Gedit",
    "Gdiffsplit",
    "Gvdiffsplit",
    "Gread",
    "Gwrite",
    "Ggrep",
    "GMove",
    "GDelete",
  },
  init = function()
    vim.g.fugitive_legacy_commands = 0

    local fugitive_augroup = vim.api.nvim_create_augroup("fugitive", { clear = true })

    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = "fugitive://*",
      group = fugitive_augroup,
      command = "set bufhidden=delete",
    })
  end,
}
