-- wilder.nvim (https://github.com/gelguy/wilder.nvim)
-- A more adventurous wildmenu

return {
  "gelguy/wilder.nvim",
  build = ":UpdateRemotePlugins",
  event = "CmdlineEnter",
  ---@type LazyKeysSpec[]
  keys = {
    { "<TAB>", 'wilder#in_context() ? wilder#next() : "\\<Tab>"', mode = "c", expr = true },
    { "<S-TAB>", 'wilder#in_context() ? wilder#previous() : "\\<S-Tab>"', mode = "c", expr = true },
    { "<C-j>", 'wilder#in_context() ? wilder#next() : "\\<Tab>"', mode = "c", expr = true },
    { "<C-k>", 'wilder#in_context() ? wilder#previous() : "\\<S-Tab>"', mode = "c", expr = true },
  },
  config = function()
    vim.opt.wildcharm = vim.fn.char2nr("	") -- tab

    local wilder = require("wilder")
    wilder.enable_cmdline_enter()
    wilder.setup({ modes = { ":", "/" } })

    wilder.set_option("pipeline", {
      wilder.debounce(10),
      wilder.branch(
        wilder.cmdline_pipeline({
          fuzzy = 1,
          -- set_pcre2_pattern = 1,
        }),
        wilder.search_pipeline()
      ),
    })

    local highlighters = {
      wilder.basic_highlighter(),
    }
    wilder.set_option(
      "renderer",
      wilder.renderer_mux({
        [":"] = wilder.popupmenu_renderer({
          highlighter = highlighters,
          pumblend = 10,
          left = { " ", wilder.popupmenu_devicons() },
        }),
        ["/"] = wilder.wildmenu_renderer({
          highlighter = highlighters,
        }),
        ["?"] = wilder.wildmenu_renderer({
          highlighter = highlighters,
        }),
      })
    )
  end,
}
