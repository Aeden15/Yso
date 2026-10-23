-- Real shared route-loop controller and embedded alias; only Mudlet transport,
-- clock, timers, and confirmed game state are substituted.
Yso = {}; yso = Yso
local root = arg and arg[1] or 'Ysindrolir'
local clock, serial, emitted, timers = 100000000, 0, {}, {}
getEpoch = function() return clock end
tempTimer = function(_, fn) serial=serial+1; timers[serial]=fn; return serial end
killTimer = function(id) timers[id]=nil end
tempAlias = function() serial=serial+1; return serial end
killAlias = function() end
cecho = function() end
send = function() end
raiseEvent = function() end
registerAnonymousEventHandler = function() serial=serial+1; return serial end
killAnonymousEventHandler = function() end
target = 'Bob'; shikstaff = 'staff123'
gmcp = {Char={Status={class='Monk'},Vitals={bal='1',eq='1'}},Room={Players={{name='Tester'}}}}
local locked, shield, affs = false, false, {}
IsTargetted = function(who) return who == target end
Yso.get_target = function() return target end
Yso.ak = {has=function(key) return affs[key] == true end}
Yso.shield = {up=function() return shield end}
Yso.emit = function(payload) emitted[#emitted+1]=payload; return true end
Yso.Combat = {RouteRegistry={
  resolve=function(id) if id=='monk_shikudo_group_damage' then return {
    id=id,namespace='Yso.off.monk.group_damage',mode='combat'} end end,
  active_ids=function() return {'monk_shikudo_group_damage'} end,
  for_mode=function() return {} end,
}}
dofile(root..'/Yso/xml/yso_modes.lua')
for _, file in ipairs{'monk_reference','combo','shikudo_forms','shikudo_ai','shikudo_execute'} do
  dofile(root..'/Monk/'..file..'.lua')
end
local F=Yso.monk.shikudo
Yso.monk.mindlock={is_locked=function() return locked end}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function alias() dofile(root..'/Monk/shdam_alias_body.lua') end
alias()
local M=Yso.off.monk.group_damage
eq(M.state.loop_enabled,true)
local function tick() return Yso.mode.tick_route_loop(M.key) end
eq(tick(),true); eq(emitted[#emitted].eq,'mind lock Bob')
eq(tick(),false); eq(#emitted,1) -- stale ready packet
-- Captured live output confirms mindlock without a BAL/EQ spend.
locked=true
eq(tick(),true); eq(emitted[#emitted].bal,'wield staff123&&adopt rain form')
eq(F.form,nil) -- sending adoption cannot confirm it
F.set_form('rain'); F.set_kata(0); gmcp.Char.Vitals.bal='0'; M.note_vitals()
gmcp.Char.Vitals.bal='1'; M.note_vitals()
eq(tick(),true); eq(M.state.last_cmd,'combo Bob kuro left kuro left frontkick left')
eq(F.kata,0); eq(tick(),false)
local function recover()
  M.note_recovery('left arm'); M.note_recovery('right arm'); M.note_recovery('legs')
end
recover(); shield=true; F.set_form('gaital'); F.set_kata(0)
eq(tick(),true); eq(M.state.last_cmd,'combo Bob shatter needle flashheel left')
eq(shield,true) -- Shatter send never clears a confirmed shield
recover(); shield=false; affs={prone=true,crushedthroat=true}
eq(tick(),true); eq(M.state.last_cmd,'dispatch Bob')
recover(); M.note_full_recovery(); affs={}; target='Alice'; locked=false
eq(tick(),true); eq(emitted[#emitted].eq,'mind lock Alice')
-- Stop/restart clears decisions but must retain physical/mental cooldown.
alias(); eq(M.state.loop_enabled,false); eq(M.state.pending,nil)
local count=#emitted; alias(); eq(tick(),false); eq(#emitted,count)
gmcp.Char.Vitals.eq='0'; M.note_vitals(); gmcp.Char.Vitals.eq='1'; M.note_vitals(); locked=true
M.state.room_players={}; M.state.melee_missing='alice'; shikstaff='staff456'
eq(tick(),true); eq(emitted[#emitted].eq,'mind crush Alice')
gmcp.Char.Vitals.eq='0'; M.note_vitals(); gmcp.Char.Vitals.eq='1'; M.note_vitals()
hadoken=10; eq(tick(),true); eq(emitted[#emitted].eq,'kai choke Alice')
-- Confirmation timeout disables offense rather than repeating the request.
clock=clock+11; eq(tick(),false); eq(M.state.loop_enabled,false)
eq(M.state.template.last_disable_reason,'confirmation_timeout')
-- Explicit retry after an unconfirmed/rejected request must not retain the
-- expired watchdog, but must still respect currently unavailable balance.
count=#emitted; alias(); eq(M.state.loop_enabled,true)
gmcp.Char.Vitals.eq='0'; eq(tick(),false); eq(#emitted,count)
gmcp.Char.Vitals.eq='1'; eq(tick(),true); eq(#emitted,count+1)
print('PASS Shikudo embedded alias/controller, opening, recovery, shield, Dispatch, target swap, ranged, timeout')
