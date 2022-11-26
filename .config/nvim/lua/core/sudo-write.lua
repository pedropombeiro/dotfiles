-- w!! to write a file as sudo
-- stolen from Steve Losh

local m = require("mapx").setup { global = "force", whichkey = true }

m.cmap("w!!", ":w ! sudo tee % > /dev/null", "Execute command under sudo")
