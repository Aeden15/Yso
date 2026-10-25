local root=arg[1] or 'Ysindrolir'
local sent={}
Yso={};send=function(command) sent[#sent+1]=command end
local E=dofile(root..'/Apostate/entourage.lua')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
assert(E==Yso.apostate.entourage)
eq(#sent,0);assert(E.passive());eq(#sent,0)
for _,name in ipairs({'','Bad&&quit','two names'}) do assert(not E.attack(name)) end
eq(#sent,0)
assert(E.attack('Saibel'));eq(sent[1],'order entourage kill Saibel')
assert(E.attack('saibel'));eq(#sent,1)
assert(E.attack('Other'));eq(sent[2],'order entourage kill Other')
assert(E.passive());eq(sent[3],'order entourage passive')
assert(E.passive());eq(#sent,3)
-- Prefer Yso.send without silently retrying a rejected send through raw send.
local attempts=0
Yso.send=function() attempts=attempts+1;return false end
assert(not E.attack('Saibel'));assert(not E.attack('Saibel'));eq(attempts,2);eq(#sent,3)
Yso.send=function(command) sent[#sent+1]=command;return true end
assert(E.passive());eq(sent[4],'order entourage passive')
assert(E.attack('Saibel'));eq(sent[5],'order entourage kill Saibel')
Yso.send=function() error('sender failed') end
assert(not E.passive())
Yso.send=function(command) sent[#sent+1]=command;return true end
assert(E.passive());eq(sent[6],'order entourage passive')
-- Cleanup remains possible after an attack send throws after partial transmission.
Yso.send=function(command) sent[#sent+1]=command;error('partial send') end
assert(not E.attack('Saibel'))
Yso.send=nil;assert(E.passive());eq(sent[8],'order entourage passive')
send=nil;assert(not E.attack('Saibel'))
-- Failed retarget/passive attempts invalidate the previous successful target cache.
send=function(command) sent[#sent+1]=command end
assert(E.attack('Saibel'))
Yso.send=function() error('uncertain retarget') end
assert(not E.attack('Other'));Yso.send=nil
local count=#sent;assert(E.attack('Saibel'));eq(#sent,count+1)
Yso.send=function() error('uncertain passive') end
assert(not E.passive());Yso.send=nil
count=#sent;assert(E.attack('Saibel'));eq(#sent,count+1)
for _,command in ipairs(sent) do
 assert(not command:find('bloodworms',1,true) and not command:find('summon',1,true))
end
print('PASS entourage commands, duplicate suppression, target validation, failure retries and partial-send cleanup')
