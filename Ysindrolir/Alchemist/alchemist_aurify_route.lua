local info = debug.getinfo(1, "S")
local source = info and info.source or ""

if source:sub(1, 1) ~= "@" then
  error("alchemist_aurify_route.lua must be loaded from disk")
end

local dir = source:sub(2):match("^(.*)[/\\][^/\\]+$") or "."
return dofile(dir .. "/Aurify route.lua")
