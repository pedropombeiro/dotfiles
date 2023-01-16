-- w!! to write a file as sudo
-- stolen from Steve Losh

local ok, mod = pcall(require, "mapx")
if not ok then
  return
end

local m = mod.setup { global = "force", whichkey = true }

m.cmap("w!!", ":w ! sudo tee % > /dev/null", "Execute command under sudo")
