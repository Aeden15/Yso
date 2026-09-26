-- Auto-exported from Mudlet package script: Yso party targeting
-- DO NOT EDIT IN XML; edit this file instead.

-- Party target calling.
--   t <name>     st, enemy, tunnelvision, and "pt Target: <Name>"
--   rlead <name> who to follow; rlead none does nothing
--   Party lines from that lead expand t <name> and do not re-announce.

Yso = Yso or {}
Yso.party_target = Yso.party_target or {}
local PT = Yso.party_target

if partyReporting == nil then partyReporting = true end
if raidLead == nil then raidLead = "" end

local function title_name(s)
  s = tostring(s or "")
  if s == "" then return "" end
  if type(s.title) == "function" then
    return s:title()
  end
  return (s:gsub("(%a)([%w']*)", function(a, b)
    return a:upper() .. b:lower()
  end))
end

local function my_name()
  local status = gmcp and gmcp.Char and gmcp.Char.Status
  return title_name(status and status.name or "")
end

function PT.apply(raw)
  local name = title_name(raw)
  if name == "" then return end
  if type(send) == "function" then
    send("st " .. name)
    send("enemy " .. name)
    if tostring(raw or ""):lower() == "none" then
      send("tunnelvision off")
    else
      send("tunnelvision on")
    end
    if partyReporting == true and not PT._from_follow then
      send("pt Target: " .. name)
    end
  end
  target = name
  local TG = Yso.targeting
  if type(TG) == "table" and type(TG.set) == "function" then
    pcall(TG.set, name, "manual", { no_ak = true, silent = true })
  end
end

function PT.set_lead(raw)
  local name = title_name(raw)
  if name == "" or name == "None" then return end
  raidLead = name
  if type(cecho) == "function" then
    cecho("<purple>      ==> Raid Lead: <yellow>" .. raidLead .. "<purple>.\n")
  end
  if partyReporting == true and type(send) == "function" then
    send("pt Following targets from " .. raidLead)
  end
end

function PT.follow(speaker, called)
  speaker = title_name(speaker)
  if speaker == "" or raidLead == "" or speaker ~= raidLead then return end
  local me = my_name()
  if me ~= "" and speaker == me then return end
  if type(expandAlias) ~= "function" then return end
  PT._from_follow = true
  local ok, err = pcall(expandAlias, "t " .. tostring(called or ""))
  PT._from_follow = false
  if not ok and type(echo) == "function" then
    echo("[Yso party] follow failed: " .. tostring(err) .. "\n")
  end
end

PT._alias = PT._alias or {}
PT._trig = PT._trig or {}

local function kill_alias(id)
  if id and type(killAlias) == "function" then pcall(killAlias, id) end
end

local function kill_trig(id)
  if id and type(killTrigger) == "function" then pcall(killTrigger, id) end
end

kill_alias(PT._alias.t)
kill_alias(PT._alias.rlead)
kill_trig(PT._trig.party)

if type(tempAlias) == "function" then
  PT._alias.t = tempAlias([[^t (\S+)$]], function()
    PT.apply(matches[2])
  end)
  PT._alias.rlead = tempAlias([[^rlead (\w+)$]], function()
    PT.set_lead(matches[2])
  end)
end

if type(tempRegexTrigger) == "function" then
  -- Target Entaro. / Target: Entaro. / TARGET Entaro. / TARGET: Entaro. / Targeting: Entaro.
  PT._trig.party = tempRegexTrigger(
    [[^\(Party\): (\w+) says, "(?:Targeting|TARGET|Target):? (\S+)\."$]],
    function()
      PT.follow(matches[2], matches[3])
    end
  )
end
