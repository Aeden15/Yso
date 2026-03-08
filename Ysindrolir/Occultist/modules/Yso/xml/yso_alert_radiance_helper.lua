-- Auto-exported from Mudlet package script: Yso_Alert_Radiance helper
-- DO NOT EDIT IN XML; edit this file instead.

-- Radiance alert helper (used by triggers below)
Yso = Yso or {}
Yso.radianceAlert = Yso.radianceAlert or {}

Yso.radianceAlert.cfg = Yso.radianceAlert.cfg or {
  SOUND = "C:/Windows/Media/Alarm01.wav",
  WIDTH = 80,
  PAD_BEFORE = 1,
  PAD_AFTER = 1,
}

function Yso.radianceAlert.center(line)
  local w = Yso.radianceAlert.cfg.WIDTH or 80
  line = tostring(line or "")
  if #line >= w then return line end
  local pad = math.floor((w - #line) / 2)
  if pad < 0 then pad = 0 end
  return string.rep(" ", pad) .. line
end

function Yso.radianceAlert.sound()
  local file = Yso.radianceAlert.cfg.SOUND or ""
  if file == "" then return end
  if type(playSoundFile) == "function" then
    pcall(playSoundFile, file)
  elseif type(playSound) == "function" then
    pcall(playSound, file)
  end
end

function Yso.radianceAlert.banner(lines, color)
  local cfg = Yso.radianceAlert.cfg
  color = color or "<red>"
  tempTimer(0, function()
    for _=1,(cfg.PAD_BEFORE or 0) do cecho("\n") end
    for _,ln in ipairs(lines) do
      cecho(color .. Yso.radianceAlert.center(ln) .. "\n")
    end
    for _=1,(cfg.PAD_AFTER or 0) do cecho("\n") end
  end)
end
