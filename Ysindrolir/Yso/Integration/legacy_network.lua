-- BEGIN YSO LEGACY NETWORK SAFETY
-- Public character refresh is suspended until a secure endpoint is verified.
-- Existing profile data remains available; no credentials belong in packages.
Legacy = Legacy or {}
Legacy.Network = Legacy.Network or {}
Legacy.NDB = Legacy.NDB or {}
Legacy.NDB.db = Legacy.NDB.db or {}
local Network = Legacy.Network
local NDB = Legacy.NDB

local function local_message(message)
  if type(Legacy.echo) == 'function' then Legacy.echo(message)
  elseif type(cecho) == 'function' then cecho('\n<white>[Legacy] '..message..'\n') end
end

function Network.local_feedback(kind, message)
  -- Do not echo message contents: reports may contain private information.
  local_message(tostring(kind or 'Feedback')..' is local-only. Discord posting is disabled; use ysocheck for diagnostics and ysoinstall for managed updates.')
  return false, 'posting_disabled'
end

function Legacy.Ideas(message) return Network.local_feedback('Ideas', message) end

local function character_name(value)
  if type(value) ~= 'string' then return nil end
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  if #value > 64 or not value:match("^[A-Za-z][A-Za-z'%-]*$") then return nil end
  return value:sub(1, 1):upper()..value:sub(2):lower()
end

local function title(value)
  return value:sub(1, 1):upper()..value:sub(2)
end

function NDB.network_status()
  local count = 0
  for _, row in pairs(NDB.db or {}) do if type(row) == 'table' then count = count + 1 end end
  return {mode='cache_only', refresh_enabled=false, reason='secure_endpoint_unverified',
    cached_records=count, online_data_stale=true}
end

function NDB.read_json_file(path)
  if type(yajl) ~= 'table' or type(yajl.to_value) ~= 'function' then return nil, 'decoder_unavailable' end
  if type(io) ~= 'table' or type(io.open) ~= 'function' then return nil, 'filesystem_unavailable' end
  local opened, file = pcall(io.open, path, 'r')
  if not opened or not file then return nil, 'file_unavailable' end
  local read_ok, content = pcall(file.read, file, '*a')
  pcall(file.close, file)
  if not read_ok or type(content) ~= 'string' or content:match('^%s*$') then return nil, 'empty_or_unreadable' end
  content = content:gsub('^\239\187\191', '')
  local decoded, data = pcall(yajl.to_value, content)
  if not decoded or type(data) ~= 'table' then return nil, 'invalid_json' end
  return data
end

function NDB.getOnline()
  local_message('NDB network refresh is disabled: no verified secure endpoint. Existing character records are cached; online status may be stale.')
  return false, 'secure_endpoint_unverified'
end

function NDB.lookup(value)
  local person = character_name(value)
  if not person then return false, 'invalid_character_name' end
  local home = type(getMudletHomeDir) == 'function' and getMudletHomeDir() or nil
  if type(home) ~= 'string' then return false, 'profile_directory_unavailable' end
  local data, why = NDB.read_json_file(home..'/Legacy/NDB/Characters/'..person..'.json')
  if not data then
    local existing = NDB.db[person]
    if type(existing) == 'table' then
      local_message('NDB '..person..': using cached profile data; secure refresh is unavailable.')
      return true, 'cached_memory'
    end
    local_message('NDB '..person..': cached character data unavailable; secure refresh is disabled.')
    return false, why or 'cache_unavailable'
  end
  local name = character_name(data.name)
  if not name or name:lower() ~= person:lower() then return false, 'cache_name_mismatch' end
  for _, key in ipairs({'city', 'class', 'house'}) do
    if type(data[key]) ~= 'string' or #data[key] > 128 then return false, 'invalid_cache_fields' end
  end
  if data.fullname ~= nil and (type(data.fullname) ~= 'string' or #data.fullname > 512) then return false, 'invalid_cache_fields' end
  local row = NDB.db[name] or {}
  local city = title(data.city)
  local fullname = data.fullname or row.title or name
  if city == '' or ((fullname == 'Romeo, the Guide' or fullname == 'Juliet, the Guide') and city == '(none)') then
    city = 'Divine'
  elseif city == '(hidden)' and type(row.city) == 'string' and row.city ~= '' then
    city = row.city
  elseif city:match('Underworld') then city = 'Underworld' end
  row.city, row.title, row.house, row.class = city, fullname, title(data.house), title(data.class)
  row.level = tonumber(data.level) or row.level
  row.xp_rank = tonumber(data.xp_rank) or row.xp_rank
  if city == 'Underworld' then row.house = 'The Profane Reaches of Demise' end
  row.cached = true
  NDB.db[name] = row
  local settings = Legacy.Settings and Legacy.Settings.NDB
  if settings and type(settings.newHL) == 'function' then pcall(settings.newHL, name) end
  if Legacy.CT and Legacy.CT.Enemies and Legacy.CT.Enemies[name] then Legacy.CT.Enemies[name] = row.class end
  local_message('NDB '..name..': loaded cached data; secure refresh is unavailable.')
  return true, 'cached_file'
end

function NDB.refresh_cache()
  local home = type(getMudletHomeDir) == 'function' and getMudletHomeDir() or nil
  if type(home) ~= 'string' then return false, 'profile_directory_unavailable' end
  local data = NDB.read_json_file(home..'/Legacy/NDB/who.json')
  if type(data) ~= 'table' or type(data.characters) ~= 'table' then
    NDB.getOnline()
    return false, 'online_cache_unavailable'
  end
  local awake, seen = {}, {}
  for _, item in pairs(data.characters) do
    local name = type(item) == 'table' and character_name(item.name)
    if name and not seen[name] then
      seen[name] = true
      awake[#awake+1] = name
      NDB.lookup(name)
    end
  end
  NDB.awake = awake
  local_message('NDB loaded cached online-player data. It is historical; secure network refresh is disabled.')
  return true, 'cached_online_list'
end
-- END YSO LEGACY NETWORK SAFETY
