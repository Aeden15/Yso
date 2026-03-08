--========================================================--
-- Yso/Core/queue.lua
--  • Compatibility shim for disk-workspace requires.
--  • SSOT queue implementation lives in: Yso.xml.yso_queue (Yso.queue)
--  • Provides a safe Q.clear() that matches current staging model.
--========================================================--

local _G = _G
local rawget = rawget
local type = type
local pcall = pcall
local require = require

-- Normalize root namespace so both _G.Yso and _G.yso exist and match.
do
  local root = rawget(_G, "Yso")
  if type(root) ~= "table" then root = rawget(_G, "yso") end
  if type(root) ~= "table" then root = {} end
  _G.Yso = root
  _G.yso = root
end

local Yso = _G.Yso

-- Ensure queue module is loaded (safe if already loaded).
pcall(require, "Yso.xml.yso_queue")

Yso.queue = Yso.queue or {}
local Q = Yso.queue

-- Clear staged lane(s)
--  • free lane is a list -> cleared to {}
--  • eq/bal/class are cleared to nil
function Q.clear(lane)
  Q._staged = Q._staged or {}
  if type(lane) == "string" and lane ~= "" then
    lane = lane:lower()
    if lane == "free" then
      Q._staged.free = {}
    else
      Q._staged[lane] = nil
    end
    return true
  end

  Q._staged.free = {}
  for k in pairs(Q._staged) do
    if k ~= "free" then Q._staged[k] = nil end
  end
  return true
end

return Q
