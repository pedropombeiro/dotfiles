-- IncrementActivator.vim (https://github.com/nishigori/increment-activator)
--  Vim Plugin for enhance to increment candidates U have defined.

return {
  "nishigori/increment-activator",
  init = function()
    vim.g.increment_activator_filetype_candidates = {
      ["_"] = {
        { "enable", "disable" },
      },
      ["home-assistant"] = {
        { "turn_off", "turn_on" },
        { "unavailable", "available" },
        { "not_home", "home" },
      },
      ruby = {
        { "be_allowed", "be_disallowed" },
        { "to", "not_to" },
      },
    }
  end
}
