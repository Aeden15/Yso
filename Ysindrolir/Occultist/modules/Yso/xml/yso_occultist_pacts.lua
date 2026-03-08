-- Auto-exported from Mudlet package script: Yso_occultist_pacts
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- yso_occultist_pacts_lowwarn.lua (DROP-IN)
-- Purpose:
--   • Parse Chaos Court pacts list output ("-pacts"/"pacts")
--   • Store remaining counts per pact-holder
--   • Print reminders:
--       (A) MISSING (not present in list) — based on expected roster
--       (B) LOW (<= threshold) — excluding Glaaki + Ascendant's thrall
--
-- Fixes:
--   • Corrects "Istria" spelling (not "Istyria")
--   • Excludes "The Ascendant's thrall" from LOW (user mapping: = Glaaki)
--   • Prevent cecho bleed (forces newline; prints next tick)
--========================================================--

_G.Yso = _G.Yso or _G.yso or {}
Yso.pacts = Yso.pacts or {}
local P = Yso.pacts

P.cfg = P.cfg or {
  threshold     = 7,
  auto_report   = true,
  quiet_when_ok = true,
  debug         = false,

  -- Exclude these signatures from LOW warnings (see _sig()).
  --  • "imperator glaaki" = Imperator Glaaki, the Eldritch
  --  • "the ascendants"   = The Ascendant's thrall (your note: = Glaaki one-summon)
  ignore_low_sig = {
    ["imperator glaaki"] = true,
    ["the ascendants"]   = true,
  },

  -- Canonical expected roster: 21 pact entries (as shown in your -pacts output).
  expected = {
    "Xenophage, Keeper of the Chaos",
    "Scrag, Tender of the Bloodleech",
    "Lycantha, Keeper of the Hounds",
    "Nemesis",
    "Hecate, Mother of Crones",
    "Rixil, the Spectre",
    "Nin'Kharsag, the Slime Master",
    "Pyradius, the Firelord",
    "Jy'Barrak Dameron, the Hand",
    "Palpatar, the Glutton of Glaak",
    "Cadmus, the Cursed Shaman",

    "Eerion, the Demon Jester",
    "Skyrax, the Skyscourge",
    "Danaeus, the Dark Savant",
    "Buul, the Chaos Chirurgeon",
    "Piridon, the Shapechanger",
    "Marduk, Eater of Souls",
    "Istria, the Pathfinder",                 -- corrected spelling
    "Imperator Glaaki, the Eldritch",
    "Arctar the Defender",
    "The Ascendant's thrall",
  },
}

P.data = P.data or {}
P.last_snapshot_at = P.last_snapshot_at or 0
P._cap = P._cap or { active = false, seen = false, snap = {} }

local function _dbg(msg)
  if P.cfg.debug then cecho("<gray>[PactsDBG] "..tostring(msg).."\n") end
end

local function _norm(s)
  s = tostring(s or "")
  s = s:gsub("^%s+",""):gsub("%s+$","")
  s = s:gsub("%s+"," ")
  s = s:gsub("[%.,;:!%?]+$","")
  return s
end

local function _key(s)
  s = _norm(s):lower()
  s = s:gsub("[^%w%s]","") -- remove punctuation
  s = s:gsub("%s+"," ")
  return s
end

-- Stable signature to survive truncation:
--   • default: first token
--   • "imperator <second>" for Imperator Glaaki
--   • "the <second>" for "The Ascendant's ..."
local function _sig(name)
  local k = _key(name)
  local a,b = k:match("^(%S+)%s*(%S*)")
  if not a or a == "" then return "" end
  if (a == "imperator" or a == "the") and b and b ~= "" then
    return a .. " " .. b
  end
  return a
end

-- ---------- roster rebuild (IMPORTANT) ----------
-- Hard reset roster on load so old "istyria" keys cannot persist.
P.roster = {}
for _, nm in ipairs(P.cfg.expected or {}) do
  local s = _sig(nm)
  if s ~= "" then
    P.roster[s] = _norm(nm)
  end
end

-- ---------- capture ----------
function P.parse_line(s)
  if not P._cap.active then return end
  s = tostring(s or "")
  local found = false

  for num, name in s:gmatch("%[%s*(%d+)%s*%]%s*([^%[]+)") do
    local n  = tonumber(num) or 0
    local nm = _norm(name)
    if nm ~= "" then
      P._cap.snap[nm] = n
      found = true
      _dbg(("captured: [%d] %s"):format(n, nm))
    end
  end

  if found then P._cap.seen = true end
end

function P.begin_capture()
  P._cap.active = true
  P._cap.seen   = false
  P._cap.snap   = {}
end

local function _index_snapshot(snapshot)
  local seen = {}          -- sig -> true
  local sig_to_count = {}  -- sig -> count

  for printed, count in pairs(snapshot or {}) do
    local s = _sig(printed)
    if s ~= "" then
      seen[s] = true
      sig_to_count[s] = tonumber(count) or 0
      -- NOTE: we do NOT overwrite canonical roster names from snapshot (prevents truncation corruption)
    end
  end

  return seen, sig_to_count
end

function P.finish_capture()
  if not P._cap.active then return end
  P._cap.active = false

  P.data = P._cap.snap or {}
  P.last_snapshot_at = os.time()

  if P.cfg.auto_report then
    -- next-tick to avoid printing on the dashed line / prompt line
    tempTimer(0, function() P.report_alerts() end)
  end
end

-- ---------- reporting ----------
function P.get_missing()
  local missing = {}
  local seen = _index_snapshot(P.data)

  for sig, display in pairs(P.roster or {}) do
    if sig ~= "" and not seen[sig] then
      missing[#missing+1] = display
    end
  end

  table.sort(missing)
  return missing
end

function P.get_low(threshold)
  threshold = tonumber(threshold or P.cfg.threshold) or 7
  local low = {}

  local _, sig_to_count = _index_snapshot(P.data)

  for sig, count in pairs(sig_to_count or {}) do
    if not (P.cfg.ignore_low_sig and P.cfg.ignore_low_sig[sig]) then
      local n = tonumber(count) or 0
      if n <= threshold then
        low[#low+1] = { name = P.roster[sig] or sig, count = n }
      end
    end
  end

  table.sort(low, function(a,b)
    if a.count == b.count then return a.name < b.name end
    return a.count < b.count
  end)

  return low, threshold
end

function P.report_alerts(threshold)
  local missing = P.get_missing()
  local low, thr = P.get_low(threshold)

  if (#missing == 0 and #low == 0) then
    if not P.cfg.quiet_when_ok then
      cecho(("\n<green>[Pacts] No MISSING pacts and no LOW pacts (<= %d).\n"):format(thr))
    end
    return
  end

  cecho("\n<yellow>[Pacts] Pact reminders:\n")

  if #missing > 0 then
    cecho("<red>[Pacts] MISSING (not present in list) — refresh these:\n")
    for _, nm in ipairs(missing) do
      cecho(("<red>  - %s\n"):format(nm))
    end
  end

  if #low > 0 then
    cecho(("<yellow>[Pacts] LOW (<= %d) — consider refreshing soon:\n"):format(thr))
    for _, row in ipairs(low) do
      local col = (row.count <= 2 and "<red>") or "<yellow>"
      cecho(("%s  [%2d] %s\n"):format(col, row.count, row.name))
    end
  end
end

function P.report_low(threshold) return P.report_alerts(threshold) end

-- ---------- Triggers (auto-install, safe reloading) ----------
Yso._trig = Yso._trig or {}
local function _killTrig(id) if id then killTrigger(id) end end

_killTrig(Yso._trig.pacts_start)
_killTrig(Yso._trig.pacts_line)
_killTrig(Yso._trig.pacts_dash)

Yso._trig.pacts_start = tempRegexTrigger(
  [[^You have formed the following pacts with members of the Chaos Court:]],
  function() P.begin_capture() end
)

Yso._trig.pacts_line = tempRegexTrigger(
  [[^\s*\[\s*\d+\s*\].*$]],
  function()
    if P._cap.active then P.parse_line(line) end
  end
)

Yso._trig.pacts_dash = tempRegexTrigger(
  [[^-{3,}\s*$]],
  function()
    if P._cap.active and P._cap.seen then
      P.finish_capture()
    end
  end
)

_dbg("pacts_lowwarn loaded")
--========================================================--
