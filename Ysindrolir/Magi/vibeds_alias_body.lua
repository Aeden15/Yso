-- Mudlet alias body for pattern: ^vibeds$
-- Paste this into the alias command box if you want the alias to load the
-- workspace helper automatically and then run the default embed sequence.

local mod_path = [[C:\Users\shuji\OneDrive\Desktop\Yso systems\Ysindrolir\Magi\magi_vibes.lua]]

if not (Yso and Yso.magi and Yso.magi.vibes and type(Yso.magi.vibes.run) == "function") then
  local ok, err = pcall(dofile, mod_path)
  if not ok then
    if type(cecho) == "function" then
      cecho(string.format("<red>[Yso:Magi:Vibes] load failed: %s<reset>\n", tostring(err)))
    end
    return
  end
end

local ok, err = pcall(Yso.magi.vibes.run)
if not ok and type(cecho) == "function" then
  cecho(string.format("<red>[Yso:Magi:Vibes] run failed: %s<reset>\n", tostring(err)))
end
