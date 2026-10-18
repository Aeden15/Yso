local root = assert(arg[1], "pass Ysindrolir root")
local function world(curing)
  local calls, timers, next_id = {}, {}, 0
  Yso = {self = {has_aff = function() return false end, is_prone = function() return false end}}
  Legacy = {Settings = {Curing = {status = curing}}}
  gmcp = {Char = {Vitals = {charstats = {"Kai: 82%"}}}}
  hadoken = 82
  registerAnonymousEventHandler = nil
  expandAlias = function(alias)
    assert(alias == "pp")
    calls[#calls + 1] = "pp"
    Legacy.Settings.Curing.status = not Legacy.Settings.Curing.status
  end
  send = function(command) calls[#calls + 1] = command end
  tempTimer = function(seconds, callback)
    assert(seconds == 5)
    next_id = next_id + 1; timers[next_id] = callback; return next_id
  end
  killTimer = function(id) timers[id] = nil end
  dofile(root .. "/Monk/kai_resource.lua")
  return Yso.monk.kai, calls, timers
end
local K, calls, timers = world(true)
assert(type(K.start_deliverance) == "function", "Deliverance activation API missing")
assert(K.burst.ready == nil)
K.on_burst("used"); assert(K.burst.ready == false)
K.on_burst("ready"); assert(K.burst.ready == true)
K.on_burst("too_much_kai"); assert(K.burst.ready == true)
K.on_burst("cooldown"); assert(K.burst.ready == false)
for _, value in ipairs({0, 80, 81, "invalid"}) do
  hadoken = value; assert(not K.start_deliverance()); assert(#calls == 0)
end
hadoken = "82"
Yso.self.has_aff = function(aff) return aff == "paralysis" end
assert(not K.start_deliverance()); assert(#calls == 0)
Yso.self.has_aff = function() return false end
Yso.self.is_prone = function() return true end
assert(not K.start_deliverance()); assert(#calls == 0)
Yso.self = nil; assert(not K.start_deliverance()); assert(#calls == 0)
Yso.self = {has_aff = function() return false end, is_prone = function() return false end}
assert(K.start_deliverance())
assert(table.concat(calls, ",") == "pp,kai deliverance")
assert(K.deliverance.state == "pending" and Legacy.Settings.Curing.status == false)
assert(not K.start_deliverance() and #calls == 2)
local stale = timers[next(timers)]
K.on_deliverance("channeling")
assert(next(timers) == nil and K.deliverance.state == "channeling")
stale(); assert(K.deliverance.state == "channeling" and #calls == 2)
K.on_deliverance("active")
assert(K.deliverance.state == "active" and not Legacy.Settings.Curing.status and #calls == 2)
K.on_deliverance("idle")
assert(K.deliverance.state == "idle" and Legacy.Settings.Curing.status and #calls == 3)
K.on_deliverance("idle"); assert(#calls == 3)
K, calls, timers = world(false)
assert(K.start_deliverance() and #calls == 1 and calls[1] == "kai deliverance")
K.on_deliverance("channeling"); K.on_deliverance("active"); K.on_deliverance("idle")
assert(#calls == 1 and not Legacy.Settings.Curing.status)
K, calls, timers = world(true)
assert(K.start_deliverance()); K.on_deliverance("channeling"); K.on_deliverance("idle")
assert(Legacy.Settings.Curing.status and #calls == 3)
K, calls, timers = world(true)
assert(K.start_deliverance()); timers[next(timers)]()
assert(K.deliverance.state == "idle" and Legacy.Settings.Curing.status and #calls == 3)
K, calls = world(true)
assert(K.start_deliverance()); Legacy.Settings.Curing.status = true
K.on_deliverance("idle"); assert(#calls == 2 and Legacy.Settings.Curing.status)
K, calls = world(true)
K.on_deliverance("channeling"); K.on_deliverance("active"); K.on_deliverance("idle")
assert(#calls == 0)
K.apply_charstats({"Kai: 95%"}); assert(hadoken == 95)
assert(type(Hadoken) == "function", "Existing live-GMCP Hadoken helper must survive scoped rebuild")
gmcp = {Char = {Vitals = {charstats = {"Kai: 82%"}}}}
assert(Hadoken() == 82 and hadoken == 82)
gmcp.Char.Vitals.charstats = {"Rage: 10"}
assert(Hadoken() == 0 and hadoken == 0, "Changing class must clear stale Kai")
gmcp.Char.Vitals.charstats = nil
assert(Hadoken() == 0)
local applied
Yso.monk.shikudo = {apply_charstats = function(list) applied = list end}
local list = {"Kai: 90%", "Form: Oak", "Kata: 1"}
K.apply_charstats(list)
assert(applied == list and hadoken == 90, "Vitals must still update Shikudo")
K.apply_charstats({"Kai: invalid"}); assert(hadoken == 0)
print("Kaido lifecycle regressions passed")
