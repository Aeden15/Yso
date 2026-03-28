-- Auto-exported from Mudlet package script: Radiance event
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- RadianceAlert_Helper_Event
--  • Provides: Yso.radianceAlert.fire(stage, who, msg)
--  • Raises:   raiseEvent("YsoRadiance", stage, who, msg)
--  • Trigger sound: C:/Windows/Media/Alarm01.wav (set on the stage triggers)
--  • Prints:   HASH banner (deferred)
--========================================================--

Yso = Yso or {}
Yso.radianceAlert = Yso.radianceAlert or {}

local RA = Yso.radianceAlert

RA.cfg = RA.cfg or {
  SOUND = "C:/Windows/Media/Alarm01.wav",
  WIDTH = 80,
  PAD_BEFORE = 1,
  PAD_AFTER  = 1,

  -- Toggle these if needed
  do_banner = true,
  do_event  = true,
}

local function center(line)
  local w = tonumber(RA.cfg.WIDTH or 80) or 80
  line = tostring(line or "")
  if #line >= w then return line end
  local pad = math.floor((w - #line) / 2)
  if pad < 0 then pad = 0 end
  return string.rep(" ", pad) .. line
end

local function hashBanner(stage)
  local banners = {
    [1] = {
      "########################################################",
      "#                    RADIANCE  (T-4)                   #",
      "#            Sparks in your mind. Get ready.           #",
      "########################################################",
    },
    [2] = {
      "########################################################",
      "#                    RADIANCE  (T-3)                   #",
      "#         Warmth begins to fill your body. MOVE.        #",
      "########################################################",
    },
    [3] = {
      "########################################################",
      "#                    RADIANCE  (T-2)                   #",
      "#          White arcs across your vision. MOVE NOW.     #",
      "########################################################",
    },
    [4] = {
      "########################################################",
      "###############  RADIANCE  (T-1)  ######################",
      "###############       IMMINENT       ###################",
      "###############    ESCAPE  NOW!!     ###################",
      "########################################################",
    },
  }
  return banners[stage]
end

local function banner(stage)
  if not RA.cfg.do_banner then return end
  local lines = hashBanner(stage)
  if not lines then return end

  -- Defer so it prints cleanly (not glued to the trigger line).
  tempTimer(0, function()
    for _=1,(RA.cfg.PAD_BEFORE or 0) do cecho("\n") end

    local color = "<yellow>"
    if stage >= 3 then color = "<red>" end

    for _,ln in ipairs(lines) do
      cecho(color .. center(ln) .. "\n")
    end

    for _=1,(RA.cfg.PAD_AFTER or 0) do cecho("\n") end
  end)
end

function RA.fire(stage, who, msg)
  who = who or "Monk"
  msg = msg or ""

  -- Raise event FIRST so your automation can react instantly.
  if RA.cfg.do_event and type(raiseEvent) == "function" then
    raiseEvent("YsoRadiance", stage, who, msg)
  end

  -- Only stage 1-4 receive the standard staged banner.
  if stage >= 1 and stage <= 4 then
    banner(stage)
  end
end
