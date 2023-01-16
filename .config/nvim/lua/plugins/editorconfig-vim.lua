-- EditorConfig (https://github.com/editorconfig/editorconfig-vim)
--  EditorConfig plugin for Vim (converts .editorconfig file properties to Vim behavior)

vim.g.editorconfig_blacklist = {
  filetype = { "git.*", "fugitive", "which_key" },
  pattern = { "\\.un~$", "scp://.*" }
}
vim.g.editorconfig_root_chdir = 1
