-- IncrementActivator.vim (https://github.com/nishigori/increment-activator)
--  Vim Plugin for enhance to increment candidates U have defined.

return {
  "nishigori/increment-activator",
  config = function()
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
  end
}
