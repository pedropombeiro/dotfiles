-- IncrementActivator.vim (https://github.com/vim-scripts/increment-activator/)
--  Enhanced to allow increment the list that you have defined

vim.g.increment_activator_filetype_candidates = {
  ["home-assistant"] = {
    { "turn_off", "turn_on" },
    { "unavailable", "available" },
    { "not_home", "home" },
  },
  ruby = {
    { "enable", "disable" },
    { "be_allowed", "be_disallowed" },
    { "to", "not_to" },
  },
}
