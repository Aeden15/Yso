-- Automatic text-trigger startup waits for fresh session evidence.
local S = Yso and Yso.session
if not (S and type(S.subscribe)=='function' and type(S.later)=='function') then return false end
S.subscribe('legacy.login', function()
enableTimer("Double checking everything is loaded")
disableTrigger("Alertness (Achaea+Imperian)")
sendGMCP([[Core.Supports.Add ["Comm.Channel 1"]])
sendGMCP([[Core.Supports.Add ["IRE.Target 1"] ]])
sendGMCP([[Core.Supports.Add ["IRE.Rift 1"]   ]])
sendGMCP([[Core.Supports.Add ["IRE.Time 1"] ]])
leaving = false
send("curing off")
send("queue add freestand touch mindseye")
S.later('legacy.login.look', 3, function() send('queue add freestand ql') end)
S.later('legacy.login.loaded', 4, function() raiseEvent('LoggedIn') end, true)
S.later('legacy.login.curing', 8, function() send('queue add freestand curing on') end, true)
send("date")
--Sets default config options
sendAll(
"config screenwidth 0", 
"config showqueuealerts on", 
"config killwarning off",
"config AutoOpenDoors on",
"config advancedcuring on",
"config UniversalAfflictionMessages on")
delLprompt = false
Defup()
end)
