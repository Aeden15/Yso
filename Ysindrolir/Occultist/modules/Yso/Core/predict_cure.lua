--========================================================--
-- Yso.predict.cure (Bayesian + Monte Carlo fused)
-- Purpose:
--   Predict which affliction was cured when enemy uses a shared herb/salve/sip.
--   Both Bayesian and Monte Carlo run in parallel; outputs are fused.
--   Uses AK (affstrack) as source of truth for affliction state / priors.
--
-- Module set:
--   Yso.predict (router, disabled by default)
--   Yso.predict.cure (interface: next(who), observe(who, action, meta))
--   Yso.predict.cure.bayes (posterior update using AK priors)
--   Yso.predict.cure.mc (particle-style update using AK priors)
--
-- Inputs: enemy eats kelp/aurum, touches tree, applies salve, sips.
-- Output: next(who) -> { pick="asthma", p=0.62, dist={ asthma=0.62, slickness=0.28, ... } }
--   dist keys = affliction names (probability that aff was cured)
--========================================================--

Yso = Yso or {}
Yso.predict = Yso.predict or {}
Yso.predict.cure = Yso.predict.cure or {}
Yso.predict.cure.bayes = Yso.predict.cure.bayes or {}
Yso.predict.cure.mc = Yso.predict.cure.mc or {}

local P = Yso.predict
local C = Yso.predict.cure
local B = Yso.predict.cure.bayes
local M = Yso.predict.cure.mc

-- Disabled by default.
P.enabled = (P.enabled == true)
P.cfg = P.cfg or {
  debug = false,
  fusion_weight_bayes = 0.5,
  fusion_weight_mc = 0.5,
  fusion_per_aff_bayes = {},
  fusion_per_aff_mc = {},
  decay_after_sec = 60,
}

local function _echo(s)
  if P.cfg.debug and type(cecho) == "function" then
    cecho(string.format("<gray>[Yso.predict] %s\n", tostring(s)))
  end
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    return tonumber(Yso.util.now()) or os.time()
  end
  local ge = rawget(_G, "getEpoch")
  if type(ge) == "function" then
    local t = tonumber(ge()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _norm(who)
  who = tostring(who or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return (who ~= "" and who:lower()) or nil
end

local function _current_target()
  return (Yso.get_target and Yso.get_target()) or Yso.target or rawget(_G, "target") or ""
end

C._last_who = C._last_who or nil

local function _check_decay(st)
  if not st or not st.last_at then return false end
  local dt = tonumber(P.cfg.decay_after_sec) or 60
  if dt <= 0 then return false end
  if (_now() - st.last_at) > dt then
    st.dist = {}
    return true
  end
  return false
end

function C.clear(who)
  if who then
    who = _norm(who)
    if who then
      if B._state then B._state[who] = nil end
      if M._state then M._state[who] = nil end
      _echo("cleared state for " .. who)
    end
  else
    B._state = {}
    M._state = {}
    C._last_who = nil
    _echo("cleared all prediction state")
  end
end

-- ---------- AK prior: likelihood aff was present (0..1) ----------
local function _ak_aff_score(aff)
  if Yso.oc and Yso.oc.ak and type(Yso.oc.ak.get_aff_score) == "function" then
    local ok, v = pcall(Yso.oc.ak.get_aff_score, aff)
    if ok and type(v) == "number" then return math.max(0, math.min(100, v)) / 100 end
  end
  local A = rawget(_G, "affstrack")
  if type(A) == "table" and type(A.score) == "table" then
    local v = A.score[aff]
    if type(v) == "number" then return math.max(0, math.min(100, v)) / 100 end
    if type(v) == "table" then
      local n = tonumber(v.current or v.score or v.value or 0) or 0
      return math.max(0, math.min(100, n)) / 100
    end
  end
  return 0.5 -- neutral prior if AK unavailable
end

-- ---------- Aff candidates per action (from curebuckets / cure_map) ----------
-- Sip: item name -> afflictions. Extend C.sip_map or add Cures.affs_in_sip to override.
C.sip_map = C.sip_map or {
  health = {"health"},
  mana = {"mana"},
  speed = {"slow"},
  blindness = {"blindness"},
  deafness = {"deafness"},
  asthma = {"asthma"},
  slickness = {"slickness"},
  anorexia = {"anorexia"},
  claustrophobia = {"claustrophobia"},
  agoraphobia = {"agoraphobia"},
  confusion = {"confusion"},
  stupidity = {"stupidity"},
  epilepsy = {"epilepsy"},
  recklessness = {"recklessness"},
  impatience = {"impatience"},
  pacifism = {"pacifism"},
  berserking = {"berserking"},
  vertigo = {"vertigo"},
  dizziness = {"dizziness"},
  nausea = {"nausea"},
  vomiting = {"vomiting"},
  haemophilia = {"haemophilia"},
  sensitivity = {"sensitivity"},
  weariness = {"weariness"},
  clumsiness = {"clumsiness"},
  hypochondria = {"hypochondria"},
  addiction = {"addiction"},
  lethargy = {"lethargy"},
  darkshade = {"darkshade"},
  scytherus = {"scytherus"},
  flushings = {"flushings"},
  paralysis = {"paralysis"},
  transfixation = {"transfixation"},
  frozen = {"frozen"},
  prone = {"prone"},
  disloyalty = {"disloyalty"},
  manaleech = {"manaleech"},
  deadening = {"deadening"},
  healthleech = {"healthleech"},
  parasite = {"parasite"},
  rebbies = {"rebbies"},
}

local function _affs_for_action(action, meta)
  meta = meta or {}
  local bucket = meta.bucket or meta.herb
  local loc = meta.loc
  local item = meta.item

  local out = {}
  local Cures = Yso.oc and Yso.oc.cures
  if Cures and Cures.affs_in_eat_bucket and type(Cures.affs_in_eat_bucket) == "function" then
    if action == "eat" and bucket then
      local list = Cures.affs_in_eat_bucket(bucket)
      if type(list) == "table" then
        for _, a in ipairs(list) do out[a] = true end
      end
    end
  end

  if action == "tree" and Cures and Cures.by_bucket and Cures.by_bucket.tree then
    for aff in pairs(Cures.by_bucket.tree) do out[aff] = true end
  end

  if action == "salve" and loc and Cures and Cures.by_bucket and Cures.by_bucket.apply then
    local part = loc:lower():gsub("s$", "") -- legs->leg, arms->arm, skin->skin
    local by_part = Cures.by_bucket.apply[loc] or Cures.by_bucket.apply[part]
    if type(by_part) == "table" then
      for aff in pairs(by_part) do out[aff] = true end
    end
  end

  -- Sip: try Cures.affs_in_sip(item) if present, else C.sip_map
  if action == "sip" and item then
    local list
    if Cures and type(Cures.affs_in_sip) == "function" then
      list = Cures.affs_in_sip(item)
    end
    if not list or (type(list) == "table" and #list == 0 and not next(list)) then
      local key = tostring(item):lower():gsub("^elixir%s+of%s+", ""):gsub("^vial%s+of%s+", ""):gsub("^vial%s+", ""):gsub("^%s+", ""):gsub("%s+$", "")
      list = C.sip_map[key] or C.sip_map[key:gsub("%s+", "")]
    end
    if type(list) == "table" then
      if list[1] then
        for _, a in ipairs(list) do out[a] = true end
      else
        for a in pairs(list) do if type(a) == "string" then out[a] = true end end
      end
    end
  end

  -- Fallback cure_map (from Yso.tgt or similar)
  local cure_map = {
    kelp = {"asthma","clumsiness","hypochondria","sensitivity","weariness","healthleech","parasite","rebbies"},
    ginseng = {"addiction","darkshade","haemophilia","lethargy","nausea","scytherus","flushings"},
  }
  if action == "eat" and bucket then
    local list = cure_map[bucket] or cure_map[bucket:lower()]
    if type(list) == "table" then
      for _, a in ipairs(list) do out[a] = true end
    end
  end

  return out
end

-- ---------- Bayesian: posterior update using AK priors ----------
function B.update(who, action, meta)
  if not P.enabled then return end
  if not who then return end

  local affs = _affs_for_action(action, meta)
  local n = 0
  for _ in pairs(affs) do n = n + 1 end
  if n == 0 then return end

  B._state = B._state or {}
  B._state[who] = B._state[who] or { dist = {}, last_at = 0 }
  local st = B._state[who]
  _check_decay(st)
  st.last_at = _now()

  local priors = {}
  local sum = 0
  for aff in pairs(affs) do
    local prior = _ak_aff_score(aff)
    if prior <= 0 then prior = 0.01 end
    priors[aff] = prior
    sum = sum + prior
  end
  if sum <= 0 then sum = 1 end
  for aff, p in pairs(priors) do
    st.dist[aff] = (st.dist[aff] or 0) * 0.3 + (p / sum) * 0.7
  end

  -- AK score 0 -> zero and renormalize
  local rsum = 0
  for aff, p in pairs(st.dist) do
    if _ak_aff_score(aff) == 0 then
      st.dist[aff] = 0
    else
      rsum = rsum + p
    end
  end
  if rsum > 0 then
    for aff, p in pairs(st.dist) do st.dist[aff] = p / rsum end
  end

  _echo(("bayes.update %s %s -> %d candidates (AK prior)"):format(who, action, n))
end

function B.next(who)
  who = _norm(who)
  if not who then return nil end
  local st = (B._state or {})[who]
  if not st or not st.dist then return nil end
  local pick, best = nil, 0
  for aff, p in pairs(st.dist) do
    if p > best then best = p; pick = aff end
  end
  return { pick = pick, p = best, dist = st.dist }
end

-- ---------- Monte Carlo: particle-style update using AK priors ----------
function M.update(who, action, meta)
  if not P.enabled then return end
  if not who then return end

  local affs = _affs_for_action(action, meta)
  local n = 0
  for _ in pairs(affs) do n = n + 1 end
  if n == 0 then return end

  M._state = M._state or {}
  M._state[who] = M._state[who] or { dist = {}, last_at = 0 }
  local st = M._state[who]
  _check_decay(st)
  st.last_at = _now()

  local keys = {}
  local weights = {}
  local wsum = 0
  for aff in pairs(affs) do
    keys[#keys+1] = aff
    local w = _ak_aff_score(aff)
    if w <= 0 then w = 0.01 end
    weights[#keys] = w
    wsum = wsum + w
  end
  if wsum <= 0 then wsum = 1 end

  local N_particles = 200
  local counts = {}
  for i = 1, N_particles do
    local r = math.random() * wsum
    local acc = 0
    for j, k in ipairs(keys) do
      acc = acc + weights[j]
      if r <= acc then counts[k] = (counts[k] or 0) + 1; break end
    end
  end
  for aff, c in pairs(counts) do
    st.dist[aff] = (st.dist[aff] or 0) * 0.3 + (c / N_particles) * 0.7
  end

  local rsum = 0
  for aff, p in pairs(st.dist) do
    if _ak_aff_score(aff) == 0 then
      st.dist[aff] = 0
    else
      rsum = rsum + p
    end
  end
  if rsum > 0 then
    for aff, p in pairs(st.dist) do st.dist[aff] = p / rsum end
  end

  _echo(("mc.update %s %s -> %d candidates (%d particles)"):format(who, action, n, N_particles))
end

function M.next(who)
  who = _norm(who)
  if not who then return nil end
  local st = (M._state or {})[who]
  if not st or not st.dist then return nil end
  local pick, best = nil, 0
  for aff, p in pairs(st.dist) do
    if p > best then best = p; pick = aff end
  end
  return { pick = pick, p = best, dist = st.dist }
end

-- ---------- Fusion: combine Bayesian + Monte Carlo ----------
local function _fuse(b_res, m_res)
  if not b_res and not m_res then return nil end
  if not b_res then return m_res end
  if not m_res then return b_res end

  local default_wb = tonumber(P.cfg.fusion_weight_bayes) or 0.5
  local per_b = P.cfg.fusion_per_aff_bayes or {}
  local per_m = P.cfg.fusion_per_aff_mc or {}

  local all_affs = {}
  for aff in pairs(b_res.dist or {}) do all_affs[aff] = true end
  for aff in pairs(m_res.dist or {}) do all_affs[aff] = true end

  local dist = {}
  for aff in pairs(all_affs) do
    local wb = tonumber(per_b[aff]) or default_wb
    local wm = tonumber(per_m[aff]) or (1 - wb)
    local s = wb + wm
    if s <= 0 then wb, wm = 0.5, 0.5; s = 1 end
    wb, wm = wb / s, wm / s
    local bp = (b_res.dist or {})[aff] or 0
    local mp = (m_res.dist or {})[aff] or 0
    dist[aff] = bp * wb + mp * wm
  end

  local pick, best = nil, 0
  for aff, p in pairs(dist) do
    if p > best then best = p; pick = aff end
  end
  return { pick = pick, p = best, dist = dist }
end

-- ---------- Public API ----------
function C.observe(who, action, meta)
  if not P.enabled then return end
  local nwho = _norm(who)
  if not nwho then return end
  if C._last_who and C._last_who ~= nwho then
    C.clear(C._last_who)
  end
  C._last_who = nwho
  B.update(nwho, action, meta)
  M.update(nwho, action, meta)
end

function C.next(who)
  if not P.enabled then return nil end
  local b_res = B.next(who)
  local m_res = M.next(who)
  return _fuse(b_res, m_res)
end

function C.dump(who)
  who = _norm(who)
  if not who then return end
  local res = C.next(who)
  if not res then
    if type(cecho) == "function" then cecho("<gray>[Yso.predict] no prediction for " .. tostring(who) .. "\n") end
    return
  end
  if type(cecho) ~= "function" then return end
  cecho(string.format("<cyan>[Yso.predict] %s: pick=%s p=%.2f\n", who, tostring(res.pick), res.p or 0))
  if res.dist then
    local keys = {}
    for k in pairs(res.dist) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, aff in ipairs(keys) do
      cecho(string.format("  %s: %.2f\n", aff, res.dist[aff] or 0))
    end
  end
end

-- ---------- Event wiring (deferred until toggle-on) ----------
local _orig_kelp, _orig_aurum, _orig_tree

local function _wire_offense_events()
  local oc = Yso.off and Yso.off.oc
  if not oc then return end

  _orig_kelp = oc.on_enemy_kelp_eat
  if type(_orig_kelp) == "function" then
    oc.on_enemy_kelp_eat = function(who)
      _orig_kelp(who)
      local tgt = _current_target()
      if tgt ~= "" then C.observe(tgt, "eat", { bucket = "kelp" }) end
    end
  end

  _orig_aurum = oc.on_enemy_aurum_eat
  if type(_orig_aurum) == "function" then
    oc.on_enemy_aurum_eat = function(who)
      _orig_aurum(who)
      local tgt = _current_target()
      if tgt ~= "" then C.observe(tgt, "eat", { bucket = "aurum" }) end
    end
  end

  _orig_tree = oc.on_enemy_tree_touch
  if type(_orig_tree) == "function" then
    oc.on_enemy_tree_touch = function(who)
      _orig_tree(who)
      local tgt = _current_target()
      if tgt ~= "" then C.observe(tgt, "tree", {}) end
    end
  end

  _echo("wired kelp/aurum/tree")
end

local function _unwire_offense_events()
  local oc = Yso.off and Yso.off.oc
  if not oc then return end
  if type(_orig_kelp) == "function" then oc.on_enemy_kelp_eat = _orig_kelp end
  if type(_orig_aurum) == "function" then oc.on_enemy_aurum_eat = _orig_aurum end
  if type(_orig_tree) == "function" then oc.on_enemy_tree_touch = _orig_tree end
  _echo("unwired kelp/aurum/tree")
end

local function _wire_salve_sip()
  if type(registerAnonymousEventHandler) ~= "function" then return end

  C._eh = C._eh or {}
  if C._eh.salve then pcall(killAnonymousEventHandler, C._eh.salve) end
  C._eh.salve = registerAnonymousEventHandler("occultist.limb.salve.applied", function(ev, who, loc)
    local tgt = _current_target()
    if tgt ~= "" then C.observe(tgt, "salve", { loc = loc or "skin" }) end
  end)

  if C._eh.sip then pcall(killAnonymousEventHandler, C._eh.sip) end
  C._eh.sip = registerAnonymousEventHandler("occultist.cure.sip", function(ev, who, item)
    local tgt = _current_target()
    if tgt ~= "" then C.observe(tgt, "sip", { item = item }) end
  end)

  _echo("wired salve/sip events")
end

local function _wire_lifecycle()
  if type(registerAnonymousEventHandler) ~= "function" then return end
  C._eh = C._eh or {}

  local function _on_clear_event()
    local tgt = _current_target()
    if tgt and tgt ~= "" then C.clear(_norm(tgt)) end
  end

  local clear_events = {
    "sysTargetDeath", "sysTargetDied",
    "gmcp.Char.Room", "sysInstallPackage",
  }
  C._eh.lifecycle = C._eh.lifecycle or {}
  for _, ev in ipairs(clear_events) do
    if C._eh.lifecycle[ev] then pcall(killAnonymousEventHandler, C._eh.lifecycle[ev]) end
    C._eh.lifecycle[ev] = registerAnonymousEventHandler(ev, _on_clear_event)
  end
  _echo("wired lifecycle clear events")
end

local function _unwire_lifecycle()
  C._eh = C._eh or {}
  if C._eh.lifecycle then
    for ev, id in pairs(C._eh.lifecycle) do
      pcall(killAnonymousEventHandler, id)
    end
    C._eh.lifecycle = {}
  end
  _echo("unwired lifecycle clear events")
end

local function _unwire_salve_sip()
  C._eh = C._eh or {}
  if C._eh.salve then pcall(killAnonymousEventHandler, C._eh.salve); C._eh.salve = nil end
  if C._eh.sip then pcall(killAnonymousEventHandler, C._eh.sip); C._eh.sip = nil end
  _echo("unwired salve/sip events")
end

function P.wire()
  _wire_offense_events()
  _wire_salve_sip()
  _wire_lifecycle()
end

function P.unwire()
  _unwire_offense_events()
  _unwire_salve_sip()
  _unwire_lifecycle()
end

function P.toggle()
  P.enabled = not P.enabled
  if P.enabled then
    P.wire()
  else
    P.unwire()
  end
  _echo("predict " .. (P.enabled and "ON" or "OFF"))
end

-- No init wiring: deferred until toggle-on

--========================================================--
