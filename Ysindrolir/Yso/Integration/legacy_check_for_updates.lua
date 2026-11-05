Legacy_Downloads()
local S = Yso and Yso.session
if S and type(S.is_ready)=='function' and S.is_ready() then sendGMCP('Core.KeepAlive') end