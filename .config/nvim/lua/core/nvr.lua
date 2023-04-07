-- Use current nvim instance as the preferred text editor (Moderm Vim)
if vim.fn.executable('nvr') ~= 0 then
  vim.env.VISUAL = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
  vim.env.GIT_EDITOR = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
end
