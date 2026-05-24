-- Mudlet alias body for pattern: ^vibeds$
-- Mudlet-native load order only: this alias does not path-probe or dofile peers.

if not (Yso and Yso.magi and Yso.magi.vibes and type(Yso.magi.vibes.run) == "function") then
  if type(cecho) == "function" then
    cecho("<red>[Yso:Magi:Vibes] helper unavailable; check package load order<reset>\n")
  end
  return
end

local ok, err = pcall(Yso.magi.vibes.run)
if not ok and type(cecho) == "function" then
  cecho(string.format("<red>[Yso:Magi:Vibes] run failed: %s<reset>\n", tostring(err)))
end
