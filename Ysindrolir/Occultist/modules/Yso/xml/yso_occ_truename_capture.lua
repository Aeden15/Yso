--========================================================--
-- yso_occ_truename_capture.lua (DROP-IN)
--  • Tracks memorised truenames from:
--      - TRUENAME CORPSE success messaging (incl. line-wrap)
--      - TRUENAMES listing output (authoritative refresh)
--  • Optional JSON persistence (Mudlet yajl if present)
--========================================================--

Yso = Yso or {}
Yso.occ = Yso.occ or {}
Yso.occ.truebook = Yso.occ.truebook or {}

local TB = Yso.occ.truebook

TB.known = TB.known or {}   -- key=lower(target), val={name="Tabethys", count=1, updated=..., source="..."}
TB.total = TB.total or 0
TB.cfg   = TB.cfg   or { persist = true, debug = false, file = "yso_truenames.json" }

local function now() return (type(getEpoch)=="function" and getEpoch()) or os.time() end

local function norm(name)
  name = tostring(name or ""):gsub("^%s+",""):gsub("%s+$","")
  if name == "" then return nil end
  return name, name:lower()
end

local function d(msg)
  if TB.cfg.debug then
    cecho(string.format("<gray>[Yso:truename] %s\n", tostring(msg)))
  end
end

function TB.set(name, count, source)
  local raw,key = norm(name); if not key then return end
  count = tonumber(count) or 0
  if count <= 0 then
    TB.known[key] = nil
  else
    local row = TB.known[key] or {}
    row.name    = raw
    row.count   = count
    row.updated = now()
    row.source  = source or row.source or "unknown"
    TB.known[key] = row
  end
end

function TB.add(name, delta, source)
  local raw,key = norm(name); if not key then return end
  delta = tonumber(delta) or 1
  local cur = (TB.known[key] and tonumber(TB.known[key].count)) or 0
  TB.set(raw, cur + delta, source or "increment")
end

function TB.get(name)
  local _,key = norm(name); if not key then return 0 end
  return (TB.known[key] and tonumber(TB.known[key].count)) or 0
end

function TB.can_utter(name) return TB.get(name) > 0 end

-- ---------- persistence (optional; yajl if present) ----------
local function _path()
  local base = (type(getMudletHomeDir)=="function" and getMudletHomeDir()) or ""
  local sep  = (package.config and package.config:sub(1,1)) or "/"
  if base ~= "" and base:sub(-1) ~= sep then base = base .. sep end
  return base .. (TB.cfg.file or "yso_truenames.json")
end

function TB.save()
  if not TB.cfg.persist then return end
  if not (yajl and yajl.to_string) then return end
  local ok,blob = pcall(yajl.to_string, { known = TB.known, total = TB.total, saved = now() })
  if not ok or not blob then return end
  local f = io.open(_path(), "w"); if not f then return end
  f:write(blob); f:close()
end

function TB.load()
  if not TB.cfg.persist then return end
  if not (yajl and yajl.to_value) then return end
  local f = io.open(_path(), "r"); if not f then return end
  local blob = f:read("*a"); f:close()
  if not blob or blob == "" then return end
  local ok,t = pcall(yajl.to_value, blob)
  if ok and type(t)=="table" then
    TB.known = type(t.known)=="table" and t.known or TB.known
    TB.total = tonumber(t.total) or TB.total
  end
end

-- ---------- TRUENAMES list refresh (authoritative) ----------
TB._refresh = TB._refresh or nil
TB._in_list = TB._in_list or false

function TB._begin_refresh()
  TB._refresh = {}
  TB._in_list = true
end

function TB._commit_refresh(total)
  if type(TB._refresh)=="table" then
    TB.known = TB._refresh
  end
  if total ~= nil then TB.total = tonumber(total) or TB.total end
  TB._refresh, TB._in_list = nil, false
  TB.save()
end

-- ---------- triggers ----------
Yso._trig = Yso._trig or {}
local TR = Yso._trig

local function safe(fn)
  return function()
    local ok,err = pcall(fn)
    if not ok then d("ERR: "..tostring(err)) end
  end
end

-- TRUENAMES: start
if TR.tn_list_start then killTrigger(TR.tn_list_start) end
TR.tn_list_start = tempRegexTrigger(
  [[^The truenames of the following souls have been divulged to you:$]],
  safe(function()
    TB._begin_refresh()
  end)
)

-- TRUENAMES: row (Name <spaces> Count)
if TR.tn_list_row then killTrigger(TR.tn_list_row) end
TR.tn_list_row = tempRegexTrigger(
  [[^\s*([A-Za-z]+)\s+(\d+)\s*$]],
  safe(function()
    if not TB._in_list then return end
    local name  = matches[2]
    local count = tonumber(matches[3]) or 0
    local raw,key = norm(name)
    TB._refresh[key] = { name = raw, count = count, updated = now(), source = "truenames" }
  end)
)

-- TRUENAMES: end + total
if TR.tn_list_end then killTrigger(TR.tn_list_end) end
TR.tn_list_end = tempRegexTrigger(
  [[^You have a total of (\d+) memorised truenames\.$]],
  safe(function()
    if not TB._in_list then return end
    local total = tonumber(matches[2]) or 0
    TB._commit_refresh(total)
  end)
)

-- Corpse capture: single-line success
if TR.tn_corpse_done then killTrigger(TR.tn_corpse_done) end
TR.tn_corpse_done = tempRegexTrigger(
  [[^.*[Tt]he truename of ([A-Za-z]+) is now yours!$]],
  safe(function()
    local who = matches[2]
    TB.add(who, 1, "corpse")
    TB.save()
  end)
)

-- Corpse capture: wrapped line 1 ends with name (your screenshot case)
TB._pending_corpse = TB._pending_corpse or nil

if TR.tn_corpse_pending then killTrigger(TR.tn_corpse_pending) end
TR.tn_corpse_pending = tempRegexTrigger(
  [[^.*[Tt]he truename of ([A-Za-z]+)\s*$]],
  safe(function()
    TB._pending_corpse = matches[2]
  end)
)

-- Corpse capture: wrapped line 2
if TR.tn_corpse_done2 then killTrigger(TR.tn_corpse_done2) end
TR.tn_corpse_done2 = tempRegexTrigger(
  [[^is now yours!$]],
  safe(function()
    if not TB._pending_corpse then return end
    local who = TB._pending_corpse
    TB._pending_corpse = nil
    TB.add(who, 1, "corpse")
    TB.save()
  end)
)

-- Optional: forget line (best-effort; harmless if it never matches)
if TR.tn_forget then killTrigger(TR.tn_forget) end
TR.tn_forget = tempRegexTrigger(
  [[^You .*forget the truename of ([A-Za-z]+)\.$]],
  safe(function()
    TB.set(matches[2], 0, "forget")
    TB.save()
  end)
)

-- load persisted data (if any) on startup/reload
TB.load()
d("truename capture loaded")
--========================================================--
