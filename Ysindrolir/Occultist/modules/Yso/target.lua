-- Auto-generated from Mudlet package script: Yso.target
-- NOTE: This is a *module wrapper* around the canonical XML script.
-- It runs once per Lua state via require cache and returns Yso.target.

local Yso = require("Yso")

-- prevent double-loading in mixed XML+disk installs
Yso._loaded = Yso._loaded or {}
if Yso._loaded['Yso.target'] then
  return Yso.target
end
Yso._loaded['Yso.target'] = true

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

-- If core target service exists, prefer it.
if type(Yso.get_target) ~= "function" and Yso.targeting and type(Yso.targeting.get) == "function" then
  function Yso.get_target() return Yso.targeting.get() end
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
      return Yso.targeting.get()
    end
    local a = tostring(arg or ""):gsub("^%s+",""):gsub("%s+$","")
    if a ~= "" then return a end
    if type(Yso.get_target) == "function" then return Yso.get_target() end
    local g = rawget(_G, "target")
    if type(g) == "string" and g ~= "" then return g end
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

--========================================================--


return Yso.target
