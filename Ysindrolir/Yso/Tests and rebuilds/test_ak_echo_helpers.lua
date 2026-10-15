-- AK display echoes are called from live tracking scripts. A missing function
-- aborts the rest of the caller, so registration has to survive a custom
-- ak.refreshAffs (odisplay returns early in that case).

local PATH_SEP = package.config:sub(1, 1)

local function script_dir()
  local source = debug.getinfo(1, "S").source or ""
  if source:sub(1, 1) == "@" then source = source:sub(2) end
  return source:match("^(.*)[/\\][^/\\]+$") or "."
end

local function join_path(...)
  local parts = { ... }
  local out = table.remove(parts, 1) or ""
  for i = 1, #parts do
    local part = tostring(parts[i] or "")
    if part ~= "" then
      if out ~= "" and out:sub(-1) ~= PATH_SEP then
        out = out .. PATH_SEP
      end
      out = out .. part
    end
  end
  return out
end

local SCRIPT_DIR = script_dir()
local AK_XML = join_path(SCRIPT_DIR, "..", "..", "mudlet packages", "AK.xml")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass(label)
  pass_count = pass_count + 1
  io.stdout:write("PASS: " .. label .. "\n")
end

local function check(label, ok, detail)
  if ok then
    pass(label)
  else
    fail(label, detail)
  end
end

local xml_file = assert(io.open(AK_XML, "rb"))
local xml = xml_file:read("*a")
xml_file:close()

local function xml_unescape(text)
  return text
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&quot;", '"')
    :gsub("&apos;", "'")
    :gsub("&amp;", "&")
end

local function extract_script(name)
  local name_at = xml:find("<name>" .. name .. "</name>", 1, true)
  if not name_at then return nil, "script name not found: " .. name end
  local script_at = xml:find("<script>", name_at, true)
  if not script_at then return nil, "script body not found: " .. name end
  local body_at = script_at + #"<script>"
  local end_at = xml:find("</script>", body_at, true)
  if not end_at then return nil, "script end not found: " .. name end
  return xml_unescape(xml:sub(body_at, end_at - 1))
end

local function load_script(name, env)
  local body, err = extract_script(name)
  if not body then return nil, err end
  local chunk, load_err = load(body, name, "t", env)
  if not chunk then return nil, load_err end
  local ok, run_err = pcall(chunk)
  if not ok then return nil, run_err end
  return true
end

local function new_env()
  local env = {}
  setmetatable(env, { __index = _G })
  return env
end

string.title = string.title or function(text)
  return (tostring(text):gsub("^%l", string.upper))
end

table.contains = table.contains or function(list, value)
  if type(list) ~= "table" then return false end
  for i = 1, #list do
    if list[i] == value then return true end
  end
  return false
end

local function assert_echo_fields(label, env)
  check(label .. " defines echogain", type(env.ak.echogain) == "function", type(env.ak.echogain))
  check(label .. " defines echolost", type(env.ak.echolost) == "function", type(env.ak.echolost))
  check(label .. " defines echoForPossibleCures", type(env.ak.echoForPossibleCures) == "function", type(env.ak.echoForPossibleCures))
  check(label .. " defines EchoForMajorAff", type(env.EchoForMajorAff) == "function", type(env.EchoForMajorAff))
end

do
  local env = new_env()
  local custom_refresh = function() end
  env.ak = { refreshAffs = custom_refresh }
  local ok, err = load_script("odisplay", env)
  check("custom refresh still loads odisplay", ok == true, err)
  if ok then
    check("custom refresh is preserved", env.ak.refreshAffs == custom_refresh)
    assert_echo_fields("custom refresh", env)
  end
end

do
  local env = new_env()
  local ok, err = load_script("odisplay", env)
  check("fresh namespace loads odisplay", ok == true, err)
  if ok then
    check("fresh namespace creates ak", type(env.ak) == "table", type(env.ak))
    assert_echo_fields("fresh namespace", env)
  end
end

do
  local env = new_env()
  env.ak = {}
  local lines = {}
  env.cecho = function(text) lines[#lines + 1] = text end
  local ok, err = load_script("odisplay", env)
  check("echo load", ok == true, err)
  if ok then
    local function call_echo(fn, text)
      if type(fn) ~= "function" then return nil, "nil echo function" end
      local call_ok, call_err = pcall(fn, text)
      if not call_ok then return nil, call_err end
      return lines[1] or ""
    end

    lines = {}
    local gained, gained_err = call_echo(env.ak.echogain, "Paralysis")
    check("echogain announces the affliction", gained ~= nil and gained:find("Paralysis", 1, true) ~= nil and gained:find("Gained", 1, true) ~= nil, gained_err or gained)

    lines = {}
    local cures, cures_err = call_echo(env.ak.echoForPossibleCures, "asthma slickness")
    check("echoForPossibleCures announces the cures", cures ~= nil and cures:find("asthma", 1, true) ~= nil and cures:find("Possible cures", 1, true) ~= nil, cures_err or cures)

    lines = {}
    local lost, lost_err = call_echo(env.ak.echolost, "Impatience")
    check("echolost announces the cleared affliction", lost ~= nil and lost:find("Impatience", 1, true) ~= nil and lost:find("Lost", 1, true) ~= nil, lost_err or lost)

    lines = {}
    env.ak.nodisplay = true
    local hidden_ok, hidden_err = pcall(function()
      env.ak.echogain("Paralysis")
      env.ak.echoForPossibleCures("asthma")
    end)
    check("nodisplay suppresses echo output", hidden_ok == true and #lines == 0, hidden_err or table.concat(lines, " | "))

    env.ak.nodisplay = false
    env.cecho = nil
    local silent_ok, silent_err = pcall(function()
      env.ak.echogain("Paralysis")
      env.ak.echoForPossibleCures("")
      env.EchoForMajorAff("PRONE")
    end)
    check("missing cecho does not throw", silent_ok == true, silent_err)
  end
end

do
  local env = new_env()
  local function custom_gain() end
  env.ak = { echogain = custom_gain, refreshAffs = function() end }
  local ok, err = load_script("odisplay", env)
  check("override load", ok == true, err)
  if ok then
    check("custom echogain is preserved", env.ak.echogain == custom_gain)
    check("other echoes still register beside a custom echogain", type(env.ak.echolost) == "function" and type(env.ak.echoForPossibleCures) == "function")
  end
end

do
  local env = new_env()
  env.ak = { refreshAffs = function() end }
  local display_ok, display_err = load_script("odisplay", env)
  local tracker_ok, tracker_err = load_script("oscore edit functions", env)
  check("gain path loads tracker", display_ok == true and tracker_ok == true, display_err or tracker_err)
  if display_ok and tracker_ok then
    local events = {}
    local scoreups = 0
    env.affstrack = {
      score = { paralysis = 0, deaf = 0 },
      venoms = {},
      mentallist = {},
      physicallist = {},
    }
    env.ak.defs = {}
    env.ak.AddedAffReset = function() end
    env.ak.scoreup = function() scoreups = scoreups + 1 end
    env.raiseEvent = function(name) events[#events + 1] = name end
    env.target = "Opponent"
    local ok, err = pcall(env.OppGainedAff, "paralysis")
    check("paralysis gain does not throw", ok == true, err)
    check("paralysis gain still raises AK got aff", events[1] == "AK got aff", events[1])
    check("paralysis gain still calls scoreup", scoreups == 1, tostring(scoreups))
    check("paralysis gain records the score", env.affstrack.score.paralysis == 100, tostring(env.affstrack.score.paralysis))
  end
end

io.stdout:write(string.format("%d passed, %d failed\n", pass_count, fail_count))
os.exit(fail_count == 0 and 0 or 1)
