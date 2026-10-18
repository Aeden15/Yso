local root = assert(arg[1], "Ysindrolir root required")
local kai = assert(loadfile(root .. "/Monk/kai_cripple_trigger.lua"))
local soar = assert(loadfile(root .. "/Airlord/soar_alias.lua"))
local gained, calls = {}, {}
local function reset()
  gained = {}
  ak = nil
  multimatches = {{"output", "Trendric"}, {"success"}}
  IsTargetted = function(name) return name == "Trendric" end
  OppGainedAff = function(affs) gained[#gained + 1] = affs end
end
reset(); kai()
assert(#gained == 1 and gained[1] == "leftleg rightleg rightarm leftarm prone")
reset(); multimatches[1][2] = "Other"; kai(); assert(#gained == 0)
reset(); ak = {ai = function() return true end}; kai(); assert(#gained == 0)
reset(); ak = {ai = function() return false end}; kai(); assert(#gained == 1)
reset(); IsTargetted = nil; kai(); assert(#gained == 0)
reset(); OppGainedAff = nil; kai()
reset(); multimatches = nil; kai(); assert(#gained == 0)
reset(); multimatches = {{}}; kai(); assert(#gained == 0)
for suffix, elevation in pairs({l="low", h="high", s="stratosphere"}) do
  calls = {}
  matches = {"soa" .. suffix, suffix}
  sendAll = function(...) calls = {...} end
  soar()
  assert(#calls == 2 and calls[1] == "clearqueue all" and calls[2] == "aero soar " .. elevation)
end
calls = {}; matches = {"soax", "x"}; soar(); assert(#calls == 0)
print("Kai/soar Lua regressions passed")
