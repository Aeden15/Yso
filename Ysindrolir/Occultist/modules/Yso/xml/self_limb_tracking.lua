-- Auto-exported from Mudlet package script: Self Limb tracking
-- DO NOT EDIT IN XML; edit this file instead.

Legacy = Legacy or {}
Legacy.Occultist = Legacy.Occultist or {}
Legacy.Occultist._eh = Legacy.Occultist._eh or {}

-- Handler signature (Legacy.SLC.Hit): (event, attacker, limb, dmg, hits, dmgTotal)
function Legacy.Occultist.onLimbHit(event, attacker, limb, dmg, hits, dmgTotal)
  -- Example filter: only care when attacker is your current target (Yso canonical target)
  local t = (type(Yso.get_target)=="function" and Yso.get_target()) or Yso.target
  if attacker and type(t)=="string" and t ~= "" and attacker:lower() ~= t:lower() then return end

  -- TODO: Your Occultist logic here (alerts, automated decisions, logging, etc.)
  -- e.g. if limb == "left leg" and hits >= 3 then ...
end

local function _kill(id) if id then killAnonymousEventHandler(id) end end
_kill(Legacy.Occultist._eh.slc_hit)
Legacy.Occultist._eh.slc_hit = registerAnonymousEventHandler("Legacy.SLC.Hit", Legacy.Occultist.onLimbHit)
