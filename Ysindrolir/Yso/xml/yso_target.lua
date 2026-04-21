-- Auto-exported from Mudlet package script: Yso.target
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso.target (compatibility shim)
--  NOTE:
--    Canonical combat targeting is implemented in Yso.targeting (Core scripts).
--    This script is intentionally minimal and should NOT redefine Yso.set_target
--    or Yso.get_target if they already exist.
--  Purpose:
--    • Keep older modules that reference Yso.target / Yso.ak.target working.
--========================================================--

Yso = Yso or {}
Yso.ak = Yso.ak or {}

-- Back-compat: keep a string field for legacy readers.
Yso.target = Yso.target or ""
Yso.targeting = Yso.targeting or {}

local TG = Yso.targeting

local function _trim_target(s)
  return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$",""))
end

if type(TG.get) ~= "function" and type(require) == "function" then
  pcall(require, "Yso.xml.yso_targeting")
  TG = Yso.targeting or TG
end

local function _target_now()
  if type(getEpoch) == "function" then
    local t = tonumber(getEpoch()) or os.time()
    if t > 20000000000 then t = t / 1000 end
    return t
  end
  return os.time()
end

local function _wake_target(reason)
  if Yso and Yso.pulse and type(Yso.pulse.wake) == "function" then
    pcall(Yso.pulse.wake, tostring(reason or "target"))
  end
end

local function _push_ak_target(name)
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    local tgt = rawget(ak, "target")
    if type(tgt) == "table" and type(tgt.set) == "function" then
      pcall(tgt.set, name, { source = "yso" })
      return true
    end
    if type(rawget(ak, "setTarget")) == "function" then
      pcall(ak.setTarget, name)
      return true
    end
  end

  if type(expandAlias) == "function" then
    expandAlias("t " .. tostring(name))
    return true
  end

  if type(send) == "function" then
    send("st " .. tostring(name))
    return true
  end

  return false
end

local function _clear_ak_target()
  local ak = rawget(_G, "ak")
  if type(ak) == "table" then
    local tgt = rawget(ak, "target")
    if type(tgt) == "table" and type(tgt.clear) == "function" then
      pcall(tgt.clear, { source = "yso" })
      return true
    end
    if type(rawget(ak, "clearTarget")) == "function" then
      pcall(ak.clearTarget)
      return true
    end
  end

  if type(expandAlias) == "function" then
    expandAlias("t clear")
    return true
  end

  if type(send) == "function" then
    send("st none")
    return true
  end

  return false
end

if type(TG.get) ~= "function" then
  function TG.get()
    local tgt = _trim_target(TG.target)
    if tgt ~= "" then return tgt end

    tgt = _trim_target(Yso.target)
    if tgt ~= "" then return tgt end

    tgt = _trim_target(rawget(_G, "target"))
    if tgt ~= "" then return tgt end

    local gmcp_tgt = ""
    if gmcp and gmcp.IRE and gmcp.IRE.Target then
      gmcp_tgt = _trim_target(gmcp.IRE.Target.Set)
    end
    if gmcp_tgt == "" and gmcp and gmcp.Char and gmcp.Char.Status then
      gmcp_tgt = _trim_target(gmcp.Char.Status.target)
    end
    if gmcp_tgt ~= "" then return gmcp_tgt end

    return nil
  end
end

if type(TG.set) ~= "function" then
  function TG.set(who, source)
    local name = _trim_target(who)
    if name == "" then
      return TG.clear(source or "manual")
    end

    _push_ak_target(name)
    TG.target = name
    TG.source = tostring(source or "manual")
    TG.at = _target_now()
    Yso.target = name
    rawset(_G, "target", name)
    _wake_target("target:set:" .. TG.source)
    return true
  end
end

if type(TG.clear) ~= "function" then
  function TG.clear(source, reason, silent)
    _clear_ak_target()
    TG.target = ""
    TG.source = tostring(source or "system")
    TG.at = _target_now()
    Yso.target = ""
    rawset(_G, "target", "")
    _wake_target("target:clear:" .. TG.source)
    return true
  end
end

if type(TG.get_target) ~= "function" then
  function TG.get_target()
    return TG.get()
  end
end

if type(TG.set_target) ~= "function" then
  function TG.set_target(name, source)
    return TG.set(name, source)
  end
end

if type(TG.clear_target) ~= "function" then
  function TG.clear_target(source, reason, silent)
    return TG.clear(source, reason, silent)
  end
end

if type(TG.is_current) ~= "function" then
  function TG.is_current(name)
    local who = _trim_target(name):lower()
    local cur = _trim_target(TG.get()):lower()
    return who ~= "" and cur ~= "" and who == cur
  end
end

if type(Yso.get_target) ~= "function" then
  function Yso.get_target()
    if Yso.targeting and type(Yso.targeting.get) == "function" then
      local ok, tgt = pcall(Yso.targeting.get)
      if ok and type(tgt) == "string" then
        tgt = _trim_target(tgt)
        if tgt ~= "" then return tgt end
      end
    end

    local tgt = _trim_target(Yso.target)
    if tgt ~= "" then return tgt end

    tgt = _trim_target(rawget(_G, "target"))
    if tgt ~= "" then return tgt end

    local gmcp_tgt = ""
    if gmcp and gmcp.IRE and gmcp.IRE.Target then
      gmcp_tgt = _trim_target(gmcp.IRE.Target.Set)
    end
    if gmcp_tgt == "" and gmcp and gmcp.Char and gmcp.Char.Status then
      gmcp_tgt = _trim_target(gmcp.Char.Status.target)
    end
    if gmcp_tgt ~= "" then return gmcp_tgt end

    return nil
  end
end

if type(Yso.set_target) ~= "function" and Yso.targeting and type(Yso.targeting.set) == "function" then
  function Yso.set_target(who, source) return Yso.targeting.set(who, source or "manual") end
end

if type(Yso.clear_target) ~= "function" and Yso.targeting and type(Yso.targeting.clear) == "function" then
  function Yso.clear_target(reason) return Yso.targeting.clear("system", reason) end
end

if type(Yso.resolve_target) ~= "function" then
  function Yso.resolve_target(arg, opts)
    opts = opts or {}
    if Yso.targeting and type(Yso.targeting.get) == "function" then
      local a = tostring(arg or ""):gsub("^%s+",""):gsub("%s+$","")
      if a ~= "" then
        if opts.set and type(Yso.set_target) == "function" then pcall(Yso.set_target, a, opts.source or "manual") end
        return a
      end
      if type(Yso.get_target) == "function" then return Yso.get_target() end
      return Yso.targeting.get()
    end
    local a = tostring(arg or ""):gsub("^%s+",""):gsub("%s+$","")
    if a ~= "" then return a end
    if type(Yso.get_target) == "function" then return Yso.get_target() end
    if type(Yso.target) == "string" and Yso.target ~= "" then return Yso.target end
    return nil
  end
end

-- AK shim: many older aliases call Yso.ak.target(arg)
if type(Yso.ak.target) ~= "function" then
  function Yso.ak.target(arg)
    return Yso.resolve_target(arg, { set = false })
  end
end

TG.target = _trim_target(TG.target or Yso.target)

--========================================================--
