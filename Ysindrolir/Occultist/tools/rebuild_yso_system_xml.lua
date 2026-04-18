local legacy_name_map = {
  ["entities.lua"] = { "entities" },
  ["hinder.lua"] = { "hinder" },
  ["party_aff.lua"] = { "party_aff" },
  ["occ_aff.lua"] = { "occ_aff_burst.lua" },
  ["route_gate.lua"] = { "route_gate" },
  ["shieldbreak.lua"] = { "Hunt - Primebond Shieldbreak Selector" },
  ["yso_ak_score_exports.lua"] = { "Yso_AK_Score_Exports.lua" },
  ["yso_mode_autoswitch.lua"] = { "Yso_mode_autoswitch.lua" },
  ["yso_modes.lua"] = { "Yso_modes.lua" },
  ["yso_occultist_affmap.lua"] = { "Yso_Occultist_Affmap.lua" },
  ["yso_offense_coordination.lua"] = { "Yso_Offense_Coordination.lua" },
  ["bootstrap.lua"] = { "Bootstrap" },
  ["softlock_gate.lua"] = { "Softlock Gate" },
  ["yso_queue.lua"] = { "Yso.queue" },
  ["yso_occultist_offense.lua"] = { "Yso.occ.offense" },
  ["yso_targeting.lua"] = { "Yso.targeting" },
}

local body_signature_map = {
  ["shieldbreak.lua"] = "yso_hunt_primebond_selector%.lua %(DROP%-IN%)",
}

local insert_before_name_map = {
  ["bash_vitals_swap.lua"] = "Bootstrap",
  ["yso_self_aff.lua"] = "Bootstrap",
  ["yso_self_curedefs.lua"] = "Bootstrap",
  ["yso_serverside_policy.lua"] = "Bootstrap",
  ["entities.lua"] = "group_damage.lua",
  ["hinder.lua"] = "entities",
  ["party_aff.lua"] = "group_damage.lua",
  ["route_gate.lua"] = "group_damage.lua",
  ["yso_occultist_companions.lua"] = "group_damage.lua",
  ["yso_targeting.lua"] = "Yso.target",
}

local retired_script_name_map = {
  ["domination_reference.lua"] = { "Domination reference" },
  ["occultism_reference.lua"] = { "Occultism reference" },
  ["tarot_reference.lua"] = { "Tarot reference" },
  ["yso_travel_router.lua"] = { "yso_travel_router.lua" },
  ["yso_travel_universe.lua"] = { "yso_travel_universe.lua" },
}

local expected_no_slot = {
  ["route_interface.lua"] = true,
  ["route_registry.lua"] = true,
  ["skillset_reference_chart.lua"] = true,
  ["yso_aeon.lua"] = true,
  ["yso_predict_cure.lua"] = true,
}

local route_promoted_files = {
  "group_damage.lua",
  "occ_aff.lua",
  "party_aff.lua",
}

local pulse_trigger_updates = {
  {
    name = "Pulse: EQ recovered",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:eq_recovered", { gag = true, echo = true })
elseif Yso and Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("eq", true, "line:eq_recovered")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Pulse: BAL recovered",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:bal_recovered", { gag = true, echo = true })
elseif Yso and Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("bal", true, "line:bal_recovered")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Pulse: BAL blocked",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:bal_blocked", { gag = true, echo = true })
elseif Yso and Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("bal", false, "line:bal_blocked")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
    regexes = {
      "You must regain balance first.",
      "Balance used:",
    },
    regex_props = { 3, 0 },
  },
  {
    name = "Pulse: EQ queued (serverside)",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:eq_queued", { gag = true, echo = true })
elseif Yso and Yso.pulse then
  if type(Yso.pulse.set_ready)=="function" then Yso.pulse.set_ready("eq", false, "line:eq_queued") end
  if type(Yso.pulse.wake)=="function" then Yso.pulse.wake("line:eq_queued") end
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Pulse: BAL queued (serverside)",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:bal_queued", { gag = true, echo = true })
elseif Yso and Yso.pulse then
  if type(Yso.pulse.set_ready)=="function" then Yso.pulse.set_ready("bal", false, "line:bal_queued") end
  if type(Yso.pulse.wake)=="function" then Yso.pulse.wake("line:bal_queued") end
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Pulse: EQ running queued cmd",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:eq_run", { gag = true, echo = true })
elseif Yso and Yso.pulse then
  if type(Yso.pulse.set_ready)=="function" then Yso.pulse.set_ready("eq", false, "line:eq_run") end
  if type(Yso.pulse.wake)=="function" then Yso.pulse.wake("line:eq_run") end
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Pulse: BAL running queued cmd",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:bal_run", { gag = true, echo = true })
elseif Yso and Yso.pulse then
  if type(Yso.pulse.set_ready)=="function" then Yso.pulse.set_ready("bal", false, "line:bal_run") end
  if type(Yso.pulse.wake)=="function" then Yso.pulse.wake("line:bal_run") end
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Pulse: EQ blocked",
    script = [[if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:eq_blocked", { gag = true, echo = true })
elseif Yso and Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("eq", false, "line:eq_blocked")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Entity Balance ready",
    script = [[Yso       = Yso       or {}
Yso.occ   = Yso.occ   or {}
Yso.occ.entity_ready = true
Yso.occ.entities_missing = false
Yso.occ.entities_missing_ts = nil
if Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:entity_ready", { gag = true, echo = true })
elseif Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("entity", true, "line:entity_ready")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end]],
  },
  {
    name = "Entity balance down",
    script = [[Yso       = Yso       or {}
Yso.occ   = Yso.occ   or {}
Yso.occ.entity_ready = false
Yso.occ.entities_missing = false
Yso.occ.entities_missing_ts = nil
if Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:entity_down", { gag = true, echo = true })
elseif Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("entity", false, "line:entity_down")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end

-- Inform pulse bus about entity outcome (success vs cooldown).
local l = tostring(line or (matches and matches[1]) or ""):lower()
local fail = l:find("you may not command another entity so soon", 1, true)
          or l:find("recover from commanding your minions", 1, true)
if Yso and Yso.pulse and type(Yso.pulse.entity_ack)=="function" then
  if fail then Yso.pulse.entity_ack("fail") else Yso.pulse.entity_ack("sent") end
end]],
  },
  {
    name = "Entity missing",
    script = [[Yso = Yso or {}
Yso.occ = Yso.occ or {}

local now = (type(getEpoch) == "function") and getEpoch() or os.time()
Yso.occ.entities_missing = true
Yso.occ.entities_missing_ts = now

-- rate-limit auto-recall
Yso.occ._call_entities_cd = Yso.occ._call_entities_cd or 0
if (now - Yso.occ._call_entities_cd) >= 2 then
  Yso.occ._call_entities_cd = now
  send("call entities")
end

if Yso and Yso.pulse and type(Yso.pulse.handle_line_event)=="function" then
  Yso.pulse.handle_line_event("line:entity_missing", { gag = true, echo = true })
elseif Yso and Yso.pulse and type(Yso.pulse.set_ready)=="function" then
  Yso.pulse.set_ready("entity", false, "line:entity_missing")
  if type(deleteLine)=="function" then pcall(deleteLine) end
end
if Yso and Yso.pulse and type(Yso.pulse.entity_ack)=="function" then
  Yso.pulse.entity_ack("missing")
end]],
  },
}

local function fail(msg)
  io.stderr:write("rebuild_yso_system_xml.lua: " .. tostring(msg) .. "\n")
  os.exit(1)
end

local function path_normalize(path)
  path = tostring(path or ""):gsub("\\", "/")
  local drive = path:match("^(%a:)")
  local prefix = ""
  if drive then
    prefix = drive .. "/"
    path = path:sub(4)
  elseif path:sub(1, 1) == "/" then
    prefix = "/"
    path = path:sub(2)
  end

  local out = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #out > 0 and out[#out] ~= ".." then
        table.remove(out)
      elseif prefix == "" then
        out[#out + 1] = part
      end
    elseif part ~= "." and part ~= "" then
      out[#out + 1] = part
    end
  end

  local joined = table.concat(out, "/")
  if prefix ~= "" then
    return prefix .. joined
  end
  return joined ~= "" and joined or "."
end

local function path_dirname(path)
  path = path_normalize(path)
  local dir = path:match("^(.*)/[^/]*$")
  if dir and dir ~= "" then
    return dir
  end
  return "."
end

local function path_join(...)
  local parts = { ... }
  if #parts == 0 then
    return "."
  end

  local path = tostring(parts[1] or "")
  for i = 2, #parts do
    local part = tostring(parts[i] or "")
    if part ~= "" then
      if path == "" or path:sub(-1) == "/" or path:sub(-1) == "\\" then
        path = path .. part
      else
        path = path .. "/" .. part
      end
    end
  end
  return path_normalize(path)
end

local function get_cwd()
  local pipe = io.popen("cd", "r")
  if not pipe then
    fail("unable to read current directory")
  end
  local line = pipe:read("*l")
  pipe:close()
  if not line or line == "" then
    fail("current directory command returned no output")
  end
  return path_normalize(line)
end

local function path_is_absolute(path)
  path = tostring(path or "")
  return path:match("^%a:[/\\]") ~= nil or path:sub(1, 1) == "/"
end

local function path_resolve(path, base)
  path = tostring(path or "")
  if path == "" then
    return path_normalize(base or get_cwd())
  end
  if path_is_absolute(path) then
    return path_normalize(path)
  end
  return path_join(base or get_cwd(), path)
end

local function read_all(path)
  local fh, err = io.open(path, "rb")
  if not fh then
    fail("unable to open " .. path .. ": " .. tostring(err))
  end
  local data = fh:read("*a")
  fh:close()
  return data
end

local function read_first_line(path)
  local fh = io.open(path, "rb")
  if not fh then
    return nil
  end
  local line = fh:read("*l")
  fh:close()
  if line then
    line = line:gsub("^\239\187\191", ""):gsub("\r$", "")
  end
  return line
end

local function path_exists(path)
  local fh = io.open(path, "rb")
  if not fh then
    return false
  end
  fh:close()
  return true
end

local function write_all(path, data)
  local fh, err = io.open(path, "wb")
  if not fh then
    fail("unable to write " .. path .. ": " .. tostring(err))
  end
  fh:write(data)
  fh:close()
end

local function xml_escape(text)
  return (tostring(text or "")
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
    :gsub("'", "&apos;"))
end

local function validate_text_chars(text, label)
  text = tostring(text or "")
  for i = 1, #text do
    local b = text:byte(i)
    if b and b < 32 and b ~= 9 and b ~= 10 and b ~= 13 then
      fail(string.format("%s contains invalid control char 0x%02X at byte %d", tostring(label or "text"), b, i))
    end
  end
  return true
end

local function get_script_title(path)
  local first = read_first_line(path)
  if not first then
    return nil
  end
  local title = first:match("^%-%- Auto%-exported from Mudlet package script: (.+)$")
  if title and title ~= "" then
    return title
  end
  return nil
end

local function list_lua_files(dir)
  local win_dir = path_normalize(dir):gsub("/", "\\")
  local cmd = string.format('cmd /C dir /B /S /A-D "%s\\*.lua"', win_dir)
  local pipe = io.popen(cmd, "r")
  if not pipe then
    fail("unable to list Lua files in " .. dir)
  end

  local out = {}
  for line in pipe:lines() do
    line = tostring(line or ""):gsub("\r", "")
    if line ~= "" then
      out[#out + 1] = path_normalize(line)
    end
  end
  pipe:close()

  table.sort(out, function(a, b)
    return a:lower() < b:lower()
  end)
  return out
end

local function basename(path)
  return tostring(path or ""):match("([^/\\]+)$") or tostring(path or "")
end

local function stem(name)
  return (tostring(name or ""):gsub("%.lua$", ""))
end

local function find_next_script_start(xml, pos)
  local search_from = pos or 1
  while true do
    local start_pos = xml:find("<Script", search_from, true)
    if not start_pos then
      return nil
    end

    local next_char = xml:sub(start_pos + 7, start_pos + 7)
    if next_char == " " or next_char == ">" then
      return start_pos
    end

    search_from = start_pos + 7
  end
end

local function parse_script_blocks(xml)
  local blocks = {}
  local pos = 1

  while true do
    local start_pos = find_next_script_start(xml, pos)
    if not start_pos then
      break
    end

    local open_end = xml:find(">", start_pos, true)
    if not open_end then
      fail("unterminated <Script> tag in XML")
    end

    local close_start, close_end = xml:find("</Script>", open_end + 1, true)
    if not close_start then
      fail("missing </Script> in XML")
    end

    local block = xml:sub(start_pos, close_end)
    local name = block:match("<name>(.-)</name>") or ""
    local script_open_start, script_open_end = block:find("<script>", 1, true)
    local script_close_start = block:find("</script>", 1, true)

    local body_start, body_end, body = nil, nil, nil
    if script_open_end and script_close_start then
      body_start = start_pos + script_open_end
      body_end = start_pos + script_close_start - 2
      if body_end < body_start then
        body = ""
      else
        body = xml:sub(body_start, body_end)
      end
    end

    blocks[#blocks + 1] = {
      start_pos = start_pos,
      close_end = close_end,
      name = name,
      body_start = body_start,
      body_end = body_end,
      body = body,
    }

    pos = close_end + 1
  end

  return blocks
end

local function find_next_trigger_start(xml, pos)
  local search_from = pos or 1
  while true do
    local start_pos = xml:find("<Trigger", search_from, true)
    if not start_pos then
      return nil
    end

    local next_char = xml:sub(start_pos + 8, start_pos + 8)
    if next_char == " " or next_char == ">" then
      return start_pos
    end

    search_from = start_pos + 8
  end
end

local function parse_trigger_blocks(xml)
  local blocks = {}
  local pos = 1

  while true do
    local start_pos = find_next_trigger_start(xml, pos)
    if not start_pos then
      break
    end

    local open_end = xml:find(">", start_pos, true)
    if not open_end then
      fail("unterminated <Trigger> tag in XML")
    end

    local close_start, close_end = xml:find("</Trigger>", open_end + 1, true)
    if not close_start then
      fail("missing </Trigger> in XML")
    end

    local block = xml:sub(start_pos, close_end)
    local name = block:match("<name>(.-)</name>") or ""
    local script_open_start, script_open_end = block:find("<script>", 1, true)
    local script_close_start = block:find("</script>", 1, true)

    local body_start, body_end, body = nil, nil, nil
    if script_open_end and script_close_start then
      body_start = start_pos + script_open_end
      body_end = start_pos + script_close_start - 2
      if body_end < body_start then
        body = ""
      else
        body = xml:sub(body_start, body_end)
      end
    end

    blocks[#blocks + 1] = {
      start_pos = start_pos,
      close_end = close_end,
      name = name,
      body_start = body_start,
      body_end = body_end,
      body = body,
    }

    pos = close_end + 1
  end

  return blocks
end

local function replace_script_body_by_name(xml, name, escaped_body)
  for _, block in ipairs(parse_script_blocks(xml)) do
    if block.name == name and block.body_start and block.body_end then
      return xml:sub(1, block.body_start - 1) .. escaped_body .. xml:sub(block.body_end + 1), true
    end
  end
  return xml, false
end

local function replace_trigger_script_by_name(xml, name, escaped_body)
  for _, block in ipairs(parse_trigger_blocks(xml)) do
    if block.name == name and block.body_start and block.body_end then
      return xml:sub(1, block.body_start - 1) .. escaped_body .. xml:sub(block.body_end + 1), true
    end
  end
  return xml, false
end

local function build_trigger_regex_xml(regexes, props, indent)
  indent = indent or "\t\t\t\t\t\t\t\t"
  local out = {}

  out[#out + 1] = indent .. "<regexCodeList>"
  if type(regexes) == "table" then
    for i = 1, #regexes do
      out[#out + 1] = indent .. "\t<string>" .. xml_escape(tostring(regexes[i] or "")) .. "</string>"
    end
  end
  out[#out + 1] = indent .. "</regexCodeList>"

  out[#out + 1] = indent .. "<regexCodePropertyList>"
  if type(props) == "table" then
    for i = 1, #props do
      out[#out + 1] = indent .. "\t<integer>" .. tostring(tonumber(props[i] or 0) or 0) .. "</integer>"
    end
  end
  out[#out + 1] = indent .. "</regexCodePropertyList>"

  return table.concat(out, "\n")
end

local function replace_trigger_regex_by_name(xml, name, regexes, props)
  for _, row in ipairs(parse_trigger_blocks(xml)) do
    if row.name == name then
      local block = xml:sub(row.start_pos, row.close_end)
      local indent = block:match("\n([ \t]*)<regexCodeList>") or "\t\t\t\t\t\t\t\t"
      local replacement = build_trigger_regex_xml(regexes, props, indent)
      local updated = block:gsub("<regexCodeList>[%s%S]-</regexCodePropertyList>", replacement, 1)
      if updated == block then
        return xml, false
      end
      return xml:sub(1, row.start_pos - 1) .. updated .. xml:sub(row.close_end + 1), true
    end
  end
  return xml, false
end

local function replace_script_body_by_signature(xml, signature_pattern, escaped_body)
  for _, block in ipairs(parse_script_blocks(xml)) do
    if block.body and block.body:find(signature_pattern) then
      return xml:sub(1, block.body_start - 1) .. escaped_body .. xml:sub(block.body_end + 1), true
    end
  end
  return xml, false
end

local function line_start_for_pos(xml, pos)
  local i = pos - 1
  while i > 0 do
    if xml:sub(i, i) == "\n" then
      return i + 1
    end
    i = i - 1
  end
  return 1
end

local function build_script_block(name, escaped_body, indent)
  indent = indent or "\t\t\t\t"
  local inner = indent .. "\t"
  return table.concat({
    indent, '<Script isActive="yes" isFolder="no">\n',
    inner, "<name>", name, "</name>\n",
    inner, "<packageName />\n",
    inner, "<script>", escaped_body, "</script>\n",
    inner, "<eventHandlerList />\n",
    indent, "</Script>\n",
  })
end

local function insert_script_before_name(xml, insert_name, escaped_body, before_name)
  for _, block in ipairs(parse_script_blocks(xml)) do
    if block.name == before_name then
      local insert_pos = line_start_for_pos(xml, block.start_pos)
      local indent = xml:sub(insert_pos, block.start_pos - 1)
      local new_block = build_script_block(insert_name, escaped_body, indent ~= "" and indent or "\t\t\t\t")
      return xml:sub(1, insert_pos - 1) .. new_block .. xml:sub(insert_pos), true
    end
  end
  return xml, false
end

local function remove_script_block_by_name(xml, name)
  for _, block in ipairs(parse_script_blocks(xml)) do
    if block.name == name then
      local remove_from = line_start_for_pos(xml, block.start_pos)
      local remove_to = block.close_end
      while true do
        local ch = xml:sub(remove_to + 1, remove_to + 1)
        if ch ~= "\r" and ch ~= "\n" then
          break
        end
        remove_to = remove_to + 1
      end
      return xml:sub(1, remove_from - 1) .. xml:sub(remove_to + 1), true
    end
  end
  return xml, false
end

local function validate_xml(xml)
  local stack = {}
  local pos = 1

  while true do
    local lt = xml:find("<", pos, true)
    if not lt then
      break
    end

    local gt = xml:find(">", lt + 1, true)
    if not gt then
      return nil, "unterminated tag near byte " .. tostring(lt)
    end

    local tag = xml:sub(lt + 1, gt - 1)
    local first = tag:sub(1, 1)

    if first ~= "?" and first ~= "!" then
      local name = tag:match("^%s*/?%s*([%w_:%.%-]+)")
      if name then
        local closing = tag:match("^%s*/") ~= nil
        local self_closing = tag:match("/%s*$") ~= nil

        if closing then
          local top = stack[#stack]
          if top ~= name then
            return nil, string.format("mismatched closing tag </%s> near byte %d", name, lt)
          end
          stack[#stack] = nil
        elseif not self_closing then
          stack[#stack + 1] = name
        end
      end
    end

    pos = gt + 1
  end

  if #stack > 0 then
    return nil, "unclosed tag <" .. tostring(stack[#stack]) .. ">"
  end

  return true
end

local function unique_names(...)
  local out = {}
  local seen = {}
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if type(value) == "table" then
      for _, item in ipairs(value) do
        if item and item ~= "" and not seen[item] then
          seen[item] = true
          out[#out + 1] = item
        end
      end
    elseif value and value ~= "" and not seen[value] then
      seen[value] = true
      out[#out + 1] = value
    end
  end
  return out
end

local script_path = path_resolve(arg and arg[0] or "rebuild_yso_system_xml.lua", get_cwd())
local tools_dir = path_dirname(script_path)
local occultist_dir = path_dirname(tools_dir)
local ysindrolir_dir = path_dirname(occultist_dir)

local xml_path = path_resolve(arg and arg[1] or path_join(ysindrolir_dir, "mudlet packages", "Yso system.xml"), get_cwd())
local mirror_root = path_resolve(arg and arg[2] or path_join(occultist_dir, "modules", "Yso", "xml"), get_cwd())
local route_root = path_resolve(arg and arg[3] or path_join(occultist_dir, "modules", "Yso", "Combat", "routes"), get_cwd())

local xml = read_all(xml_path)
validate_text_chars(xml, "base XML: " .. xml_path)
local updated = {}
local no_slot = {}
local skipped = {}
local removed = {}
local trigger_updated = {}
local trigger_missing = {}

local source_files = list_lua_files(mirror_root)
for _, file_name in ipairs(route_promoted_files) do
  local promoted = path_join(route_root, file_name)
  if path_exists(promoted) then
    source_files[#source_files + 1] = promoted
  end
end

for _, path in ipairs(source_files) do
  local name = basename(path)
  local body = read_all(path)
  validate_text_chars(body, "source Lua: " .. path)
  local escaped_body = xml_escape(body)
  local title = get_script_title(path)
  local candidates = unique_names(name, title, legacy_name_map[name] or {})

  local matched = false
  for _, candidate in ipairs(candidates) do
    local new_xml
    new_xml, matched = replace_script_body_by_name(xml, candidate, escaped_body)
    if matched then
      xml = new_xml
      updated[#updated + 1] = name .. " -> " .. candidate
      break
    end
  end

  if not matched and body_signature_map[name] then
    local new_xml
    new_xml, matched = replace_script_body_by_signature(xml, body_signature_map[name], escaped_body)
    if matched then
      xml = new_xml
      updated[#updated + 1] = name .. " -> body_signature"
    end
  end

  if not matched and insert_before_name_map[name] then
    local insert_name = title or stem(name)
    local new_xml
    new_xml, matched = insert_script_before_name(xml, insert_name, escaped_body, insert_before_name_map[name])
    if matched then
      xml = new_xml
      updated[#updated + 1] = name .. " -> inserted_before:" .. insert_before_name_map[name]
    end
  end

  if not matched then
    if expected_no_slot[name] then
      no_slot[#no_slot + 1] = name
    else
      skipped[#skipped + 1] = name
    end
  end
end

for file_name, slot_names in pairs(retired_script_name_map) do
  local retired_path = path_join(mirror_root, file_name)
  if not path_exists(retired_path) then
    for _, slot_name in ipairs(slot_names) do
      local new_xml, matched = remove_script_block_by_name(xml, slot_name)
      if matched then
        xml = new_xml
        removed[#removed + 1] = slot_name
      end
    end
  end
end

for i = 1, #pulse_trigger_updates do
  local row = pulse_trigger_updates[i]
  validate_text_chars(row.script, "trigger script: " .. tostring(row.name))
  local escaped_body = xml_escape(row.script)
  local new_xml, matched = replace_trigger_script_by_name(xml, row.name, escaped_body)
  if matched then
    xml = new_xml
    trigger_updated[#trigger_updated + 1] = row.name
  else
    trigger_missing[#trigger_missing + 1] = row.name
  end
  if matched and type(row.regexes) == "table" and type(row.regex_props) == "table" then
    local regex_xml, regex_matched = replace_trigger_regex_by_name(xml, row.name, row.regexes, row.regex_props)
    if regex_matched then
      xml = regex_xml
    else
      trigger_missing[#trigger_missing + 1] = row.name .. " (regex)"
    end
  end
end

validate_text_chars(xml, "rebuilt XML (pre-write)")

local ok, err = validate_xml(xml)
if not ok then
  fail("XML validation failed before write: " .. tostring(err))
end

write_all(xml_path, xml)

local reloaded = read_all(xml_path)
validate_text_chars(reloaded, "rebuilt XML (post-write)")
local ok_after, err_after = validate_xml(reloaded)
if not ok_after then
  fail("XML validation failed after write: " .. tostring(err_after))
end

io.write(string.format("updated=%d\n", #updated))
if #updated > 0 then
  io.write("updated_files=" .. table.concat(updated, ", ") .. "\n")
end
if #removed > 0 then
  io.write("removed_slots=" .. table.concat(removed, ", ") .. "\n")
end
if #no_slot > 0 then
  io.write("no_slot_files=" .. table.concat(no_slot, ", ") .. "\n")
end
if #skipped > 0 then
  io.write("skipped_files=" .. table.concat(skipped, ", ") .. "\n")
end
if #trigger_updated > 0 then
  io.write("updated_triggers=" .. table.concat(trigger_updated, ", ") .. "\n")
end
if #trigger_missing > 0 then
  io.write("missing_triggers=" .. table.concat(trigger_missing, ", ") .. "\n")
end
