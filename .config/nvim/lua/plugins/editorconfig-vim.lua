-- EditorConfig (https://github.com/editorconfig/editorconfig-vim)
--  EditorConfig plugin for Vim (converts .editorconfig file properties to Vim behavior)

return {
  "editorconfig/editorconfig-vim",
  init = function()
    vim.g.editorconfig_blacklist = {
      filetype = { "git.*", "fugitive", "lazy", "neotest-summary", "neo-tree", "Outline", "which_key" },
      pattern = { "\\.un~$", "scp://.*" }
    }
    vim.g.editorconfig_root_chdir = 1
  end
}
