--========================================================--
-- Monk Shikudo form and kata
--  gmcp.Char.Vitals.charstats while the staff art is active includes
--  "Form: <name>" and "Kata: <number>". Both change during play.
--  Form is matched to a key in the stances table in the Shikudo scripts.
--  Kata is whatever whole number GMCP sends. GMCP is the source of truth.
--========================================================--

Yso = Yso or {}
Yso.monk = Yso.monk or {}
Yso.monk.shikudo = Yso.monk.shikudo or {}

local F = Yso.monk.shikudo

F.form = F.form
F.kata = tonumber(F.kata) or 0

local PROSE_KEYS = {
  tykonos = "tykonos",
  willow = "willow",
  ["willows shaken by the wind"] = "willow",
  rain = "rain",
  ["willows in rain storm"] = "rain",
  oak = "oak",
  ["live oak"] = "oak",
  ["the live oak"] = "oak",
  gaital = "gaital",
  maelstrom = "maelstrom",
  ["unrelenting storm"] = "maelstrom",
  ["the unrelenting storm"] = "maelstrom",
}

local function _form_key(word)
  if PROSE_KEYS[word] then return PROSE_KEYS[word] end
  local stances = rawget(_G, "stances")
  if type(stances) ~= "table" then return word end
  if stances[word] then return word end
  for key in pairs(stances) do
    if tostring(key):lower() == word then return key end
  end
  return word
end

local function _publish()
  _G.shikudoForm = F.form
  _G.shikudostance = F.form or ""
  _G.stance = F.form or ""
  _G.kata = F.kata
  _G.katachain = tostring(F.kata)
end

-- Text confirmations own banner output; GMCP form updates remain quiet.
local FORM_BANNERS = {
  tykonos = {marks='70,130,180', brackets='112,128,144', title='224,255,255',
    text='TYKONOS — TURN ASIDE THE BLOW', top='<< | >> << | >>', bottom='<< | >> << | >>'},
  willow = {marks='0,100,0', brackets='34,139,34', title='50,205,50',
    text='WILLOW — SWIFT AS THE WIND', top='>>> >>> >>>', bottom='>>> >>> >>>'},
  rain = {marks='47,79,79', brackets='112,128,144', title='192,192,192',
    text='RAIN — RELENTLESS ASSAULT', top='/// /// ///', bottom='/// /// ///'},
  oak = {marks='139,69,19', brackets='178,34,34', title='255,0,0',
    text='OAK — CRUSHING POWER', top='### === ###', bottom='### === ###'},
  gaital = {marks='72,61,139', brackets='112,128,144', title='216,191,216',
    text='GAITAL — THROUGH THE GUARD', top='... / ... / ...', bottom='... / ... / ...'},
  maelstrom = {marks='0,0,139', brackets='112,128,144', title='192,192,192',
    text='MAELSTROM — THE UNRELENTING STORM', top='~>> ~>> ~>>', bottom='<<~ <<~ <<~'},
}

function F.show_form_banner(form)
  form = _form_key(tostring(form or ''):lower():gsub('^%s+', ''):gsub('%s+$', ''))
  local row = FORM_BANNERS[form]
  if not row or F.form ~= form or F._banner_form == form or type(decho) ~= 'function' then return false end
  decho('\n<' .. row.marks .. '>      ' .. row.top .. '\n'
    .. '<' .. row.brackets .. '>  [ <' .. row.title .. '>' .. row.text
    .. '<' .. row.brackets .. '> ]\n'
    .. '<' .. row.marks .. '>      ' .. row.bottom .. '\n<r>')
  F._banner_form = form
  return true
end

function F.set_form(word)
  local previous = F.form
  word = tostring(word or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if word == "" or word == "none" then
    F.form = nil
  else
    F.form = _form_key(word)
  end
  if F.form ~= previous then F.kata = 0 end -- a new form resets kata
  if F.form ~= previous or F.form == nil then F._banner_form = nil end
  _publish()
  return F.form
end

function F.set_kata(n)
  n = tonumber(n) or 0
  if n < 0 then n = 0 end
  F.kata = n
  _publish()
  return F.kata
end

function F.apply_charstats(list)
  if type(list) ~= "table" then return F.form end
  local form, chain, tekura
  for _, entry in ipairs(list) do
    local label, value = tostring(entry or ""):match("^(.-):%s*(.*)$")
    if label then
      label = label:gsub("^%s+", ""):gsub("%s+$", ""):lower()
      if label == "form" then form = value end
      if label == "kata" then chain = value end
      if label == "stance" then tekura = value end
    end
  end
  if form ~= nil then
    F.set_form(form)
  elseif tekura ~= nil then
    local key = tostring(tekura):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if PROSE_KEYS[key] then
      F.set_form(key)
    else
      F.set_form('none')
      F.set_kata(0)
    end
  end
  if chain ~= nil then F.set_kata(chain) end
  return F.form
end

function F.current_form()
  local stats = gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.charstats
  if type(stats) == 'table' then
    F.apply_charstats(stats)
    for _, entry in ipairs(stats) do
      if tostring(entry):lower():match('^form:%s*') or tostring(entry):lower():match('^stance:%s*') then
        return F.form
      end
    end
  end
  for _, value in ipairs({F.form or '', shikudoForm or '', shikudostance or '', stance or ''}) do
    local key = tostring(value):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if PROSE_KEYS[key] then
      if F.form ~= PROSE_KEYS[key] then F.set_form(key) end
      return F.form
    end
  end
end

local function _on_vitals()
  local g = rawget(_G, "gmcp")
  local stats = g and g.Char and g.Char.Vitals and g.Char.Vitals.charstats
  F.apply_charstats(stats)
end

if type(registerAnonymousEventHandler) == "function" then
  if F._eh and type(killAnonymousEventHandler) == "function" then killAnonymousEventHandler(F._eh) end
  F._eh = registerAnonymousEventHandler("gmcp.Char.Vitals", _on_vitals)
end

-- Inventory IDs are session data; never hard-code a character's item number.
local F = Yso.monk.shikudo
F.staffs = F.staffs or {}

local function item_id(value)
  if type(value) == 'table' then value = value.id end
  local id = tostring(value or ''):match('^(%d+)$')
  return id
end

local function capture(item, partial)
  if type(item) ~= 'table' then return end
  local id = item_id(item)
  if not id then return end
  local old = F.staffs[id]
  local name = tostring(item.name or (partial and old and old.name) or '')
  if not name:lower():match('%f[%a]staff%f[%A]') then
    F.staffs[id] = nil
    return
  end
  F.staffs[id] = {id=id, name=name, attrib=item.attrib or (old and old.attrib) or ''}
end

function F.capture_staffs(packet, action)
  if type(packet) ~= 'table' or packet.location ~= 'inv' then return end
  if action == 'List' then
    if type(packet.items) ~= 'table' then return end
    F.staffs = {}
    for _, item in ipairs(packet.items) do capture(item) end
  elseif action == 'Remove' then
    local id = item_id(packet.item)
    if id then F.staffs[id] = nil end
  else
    capture(packet.item, action == 'Update')
  end
end

-- Returns a numeric ID string suitable for 'staff' .. id. The material
-- selector is independent of the current combat form: rain still uses willow.
function F.get_staff_id(material)
  material = tostring(material or 'willow'):lower()
  if material == '' then return nil end
  local ids = {}
  for id, item in pairs(F.staffs) do
    if item.name:lower():find(material, 1, true) then ids[#ids+1] = id end
  end
  table.sort(ids, function(a,b) return tonumber(a) < tonumber(b) end)
  for _, id in ipairs(ids) do
    if F.staffs[id].attrib:find('l',1,true) then return id end
  end
  return ids[1]
end

function F.refresh_staffs()
  if type(sendGMCP) == 'function' then sendGMCP('Char.Items.Inv ""') end
end

function F.staff_command()
  local configured = tostring(rawget(_G, 'shikstaff') or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if configured ~= '' then
    if configured:match('^staff%d+$') then return 'wield ' .. configured end
    if type(cecho) == 'function' then cecho('<orange>[SHIKUDO] Set shikstaff to a staff item name such as staff123.<reset>\n') end
    return nil
  end
  local id = F.get_staff_id('willow')
  if id then return 'wield staff' .. id end
  F.refresh_staffs()
  if type(cecho) == 'function' then cecho('<orange>[SHIKUDO] No willow staff found in inventory. Refresh requested; retry after it arrives.<reset>\n') end
end

function F.resolve_target()
  local who = rawget(_G,'target')
  if (who == nil or tostring(who) == '') and type(Yso.get_target) == 'function' then
    local ok, value = pcall(Yso.get_target)
    if ok then who = value end
  end
  who = tostring(who or ''):gsub('^%s+',''):gsub('%s+$','')
  if who == '' or who:find('[|\r\n]') then
    cecho('<orange>[SHIKUDO] Set a target first.<reset>\n')
    return nil
  end
  return who
end

F._inventory_handlers = F._inventory_handlers or {}
local function bind(event, fn)
  if type(registerAnonymousEventHandler) ~= 'function' then return end
  if F._inventory_handlers[event] and type(killAnonymousEventHandler) == 'function' then
    killAnonymousEventHandler(F._inventory_handlers[event])
  end
  F._inventory_handlers[event] = registerAnonymousEventHandler(event,fn)
end
for _, action in ipairs({'List','Add','Update','Remove'}) do
  local kind = action
  bind('gmcp.Char.Items.' .. kind, function()
    local items = gmcp and gmcp.Char and gmcp.Char.Items
    F.capture_staffs(items and items[kind], kind)
  end)
end
local function clear_session()
  F.staffs = {}
  F.set_form('none')
  F.set_kata(0)
end
bind('sysDisconnectionEvent', clear_session)
bind('sysConnectionEvent', function() clear_session(); F.refresh_staffs() end)
local items = gmcp and gmcp.Char and gmcp.Char.Items
if items then F.capture_staffs(items.List,'List') end
F.apply_charstats(gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.charstats)
if gmcp and gmcp.Char then F.refresh_staffs() end

-- Initialize flags without overwriting live state on a script reload.
for _, name in ipairs({'targshield','tpla','tpll','tph','tpto','tpra','tprl'}) do
  if rawget(_G,name) == nil then _G[name] = false end
end
