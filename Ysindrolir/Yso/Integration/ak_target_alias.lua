-- Maintained body for AK's ^t (.+)$ alias. Keep the request local across callbacks.
local requested = tostring(matches[2] or ""):gsub("^%s+", ""):gsub("%s+$", "")
if requested == "" then return end
ak = ak or {}
ak._target_hl = ak._target_hl or {}
local HL = ak._target_hl
local function clear_highlight()
  for _, key in ipairs({ "raw", "title" }) do
    if HL[key] and type(killTrigger) == "function" then pcall(killTrigger, HL[key]) end
    HL[key] = nil
  end
end

local key = requested:lower()
if key == "none" or key == "clear" or key == "off" or key == "nil" or key == "null" then
  local TG = Yso and Yso.targeting
  if TG and type(TG.clear) == "function" then
    TG.clear("ak", "manual_clear", true, { no_ak = true })
  else
    clear_highlight()
    if type(ak.oresetparse) == "function" then pcall(ak.oresetparse) end
    rawset(_G, "target", "")
  end
  if type(send) == "function" then send("st none") end
  if type(cecho) == "function" then cecho("\n<cyan> Target cleared\n\n") end
  return
end

local previous = tostring(rawget(_G, "target") or "")
if Yso and type(Yso.get_target) == "function" then
  local ok, value = pcall(Yso.get_target)
  if ok and type(value) == "string" then previous = value end
end
local ok, titled = pcall(function() return requested:title() end)
if ok and type(titled) == "string" and titled ~= "" then requested = titled end
rawset(_G, "target", requested)

if ak.highlighttarget == nil then ak.highlighttarget = true end
clear_highlight()
if ak.highlighttarget and type(tempTrigger) == "function" then
  local quoted = string.format("%q", requested)
  HL.title = tempTrigger(requested, "selectString(" .. quoted .. ", 1) fg('red') resetFormat()")
end
if Yso and type(Yso.set_target) == "function" then
  Yso.set_target(requested, "ak", { prev = previous, keep_class_queue = true, keep_rawsend = true })
end
local core = Yso and Yso.off and Yso.off.core
if core and type(core.tick) == "function" then pcall(core.tick, "target_change") end
if ak.stack == "none" and type(ak.classenable) == "function" then ak.classenable() end
if type(cecho) == "function" then cecho("\n<cyan> Target Changed to " .. requested .. "\n\n") end
if type(send) == "function" then send("st " .. requested) end
if type(ak.oresetparse) == "function" then ak.oresetparse() end
