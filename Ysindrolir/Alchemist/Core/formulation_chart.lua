Yso = Yso or {}
Yso.alc = Yso.alc or {}
Yso.alc.form = Yso.alc.form or {}

local F = Yso.alc.form

F.chart_rows = F.chart_rows or {
  { "Endorphin",       "healing gas" },
  { "Nutritional",     "nutrition/administer supplement" },
  { "Corrosive",       "aoe shield break" },
  { "Petrifying",      "physical resist, lightning weakness" },
  { "Incendiary",      "burning room gas" },
  { "Alteration",      "adjust/amalgamate compounds" },
  { "Devitalisation",  "max health drain gas" },
  { "Intoxicant",      "lung paralysis gas" },
  { "Vaporisation",    "remove flooded/iced room" },
  { "Phosphorous",     "strong blindness flash" },
  { "Monoxide",        "disorient/prone/balance loss" },
  { "Toxin",           "vyoria plague gas" },
  { "Concussive",      "room knockback explosion" },
  { "Mayology",        "destructive speed serum; fatal" },
  { "Halophilic",      "special vine killer" },
  { "Enhancement",     "durability/self-control form" },
  { "Bolster",         "enhanced-form heal" },
}

local function _pad(text, width)
  text = tostring(text or "")
  return text .. string.rep(" ", math.max(0, width - #text))
end

local function _strip_tags(text)
  return tostring(text or ""):gsub("<[^>]*>", "")
end

function F.show_chart()
  local win = "Yso_Formulation_Chart"
  local rows = F.chart_rows or {}

  local function out(line)
    line = tostring(line or "")
    if type(cecho) == "function" then
      cecho(win, line .. "\n")
    elseif type(echo) == "function" then
      echo(win, _strip_tags(line) .. "\n")
    end
  end

  if type(openUserWindow) == "function" then
    openUserWindow(win, false, false, "f")

    if type(setUserWindowTitle) == "function" then
      pcall(setUserWindowTitle, win, "Formulation Chart")
    end

    if type(resizeWindow) == "function" then
      pcall(resizeWindow, win, 620, 430)
    end

    if type(setFontSize) == "function" then
      pcall(setFontSize, win, 10)
    end

    if type(setWindowWrap) == "function" then
      pcall(setWindowWrap, win, 90)
    end

    if type(clearWindow) == "function" then
      clearWindow(win)
    end

    out("<gold>[FORMULATION:] <aquamarine>Quick effect chart")
    out("<gray>" .. string.rep("-", 58))
    out("<gold>" .. _pad("Skill", 18) .. " <aquamarine>Effect")
    out("<gray>" .. string.rep("-", 58))

    for _, row in ipairs(rows) do
      out("<white>" .. _pad(row[1], 18) .. " <aquamarine>" .. row[2])
    end

    out("<gray>" .. string.rep("-", 58))
    out("<aquamarine>Alias: <white>fchart")
    return
  end

  -- Main-window fallback if user windows are unavailable.
  cecho("\n<gold>[FORMULATION:] <aquamarine>Quick effect chart\n")
  cecho("<gray>" .. string.rep("-", 58) .. "\n")
  cecho("<gold>" .. _pad("Skill", 18) .. " <aquamarine>Effect\n")
  cecho("<gray>" .. string.rep("-", 58) .. "\n")

  for _, row in ipairs(rows) do
    cecho("<white>" .. _pad(row[1], 18) .. " <aquamarine>" .. row[2] .. "\n")
  end

  cecho("<gray>" .. string.rep("-", 58) .. "\n")
end
