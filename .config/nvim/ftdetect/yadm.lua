vim.filetype.add({
  pattern = {
    -- Detect filetype from extension before ## (e.g., file.sh##os.Linux -> sh)
    [".*%.(%a+)##.*"] = function(_, _, capture)
      return capture
    end,
    -- Detect filetype from e%.<ext> suffix after ## (e.g., file##template.e%.zsh -> zsh)
    [".*##.*e%.(%a+)$"] = function(_, _, capture)
      return capture
    end,
  },
})
