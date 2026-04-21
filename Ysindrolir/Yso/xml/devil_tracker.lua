-- Auto-exported from Mudlet package script: Devil tracker
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso.tarot.devil  — simple state helper
--  • Tracks Devil "possessing you" buff (30s-ish)
--  • Text-based: fling + leave/suppress lines
--========================================================--

Yso       = Yso       or {}
Yso.tarot = Yso.tarot or {}

local Devil = Yso.tarot.devil or {}
Yso.tarot.devil = Devil

local function _now()
  if type(getEpoch) == "function" then return getEpoch() end
  return os.time()
end

-- called when you successfully fling Devil at ground
function Yso.tarot.devil_up()
  Devil.active     = true
  Devil.last_cast  = _now()
  Devil.expires_at = Devil.last_cast + 30   -- safety, in case we miss the "leave" line
end

-- called when he leaves or is suppressed
function Yso.tarot.devil_down()
  Devil.active     = false
  Devil.expires_at = nil
end

-- boolean: is the Devil currently sitting on you, ready to consume the next tarot?
function Yso.tarot.devil_active()
  if Devil.active and Devil.expires_at and _now() > Devil.expires_at then
    -- hard timeout in case we never saw the leave/suppress text
    Devil.active     = false
    Devil.expires_at = nil
  end
  return Devil.active == true
end
