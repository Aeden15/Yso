-- Dynamic Magi equipment. Item IDs are discovered, never permanent settings.
Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.weapons = Yso.magi.weapons or {}
local W = Yso.magi.weapons
W.initialized = true
W.ids = W.ids or { staff = '', shield = '' }
W.inventory = W.inventory or {}
W.handlers = W.handlers or {}
W.pending_listings = W.pending_listings or {}
W.authenticated = Yso.session and Yso.session.is_ready() or false
local kinds = { staff = true, shield = true }
local function trim(s) return tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '') end
local function digits(s) return tostring(s or ''):match('^(%d+)$') or tostring(s or ''):match('^%a+(%d+)$') end
local function classify(item)
  local name = trim(item.name):lower()
  if name:find('elemental staff', 1, true) then return 'staff' end
  if name:find('%f[%a]shield%f[%A]') then return 'shield' end
end
local function wielded(item)
  local attrs = tostring(item.attrib or '')
  return attrs:find('l', 1, true) or attrs:find('L', 1, true)
end
function W.resolve()
  for kind in pairs(kinds) do
    local candidates, held = {}, {}
    for id, item in pairs(W.inventory) do
      if classify(item) == kind then
        candidates[#candidates+1] = id
        if wielded(item) then held[#held+1] = id end
      end
    end
    local old = W.ids[kind]
    local selected = ''
    if #held == 1 then selected = held[1]
    elseif #held == 0 then
      if old and W.inventory[old] and classify(W.inventory[old]) == kind then selected = old
      elseif #candidates == 1 then selected = candidates[1] end
    end
    W.ids[kind] = selected
    _G[kind == 'staff' and 'magistaff' or 'magishield'] = selected ~= '' and kind .. selected or ''
  end
end
function W.capture_items(data, action)
  if type(data) ~= 'table' or data.location ~= 'inv' then return end
  if action == 'List' then
    if type(data.items) ~= 'table' then return end
    W.inventory = {}
    for _, item in ipairs(data.items) do
      if type(item) == 'table' and digits(item.id) then W.inventory[digits(item.id)] = item end
    end
  else
    local item = data.item
    local id = digits(type(item) == 'table' and item.id or item)
    if not id then return end
    if action == 'Remove' then W.inventory[id] = nil
    elseif type(item) == 'table' then
      local merged = {}
      for k,v in pairs(W.inventory[id] or {}) do merged[k]=v end
      for k,v in pairs(item) do merged[k]=v end
      W.inventory[id] = merged
    end
  end
  W.resolve()
end
function W.set(kind, id)
  kind = trim(kind):lower(); id = digits(id)
  if not kinds[kind] or not id or not W.inventory[id] or classify(W.inventory[id]) ~= kind then return false end
  W.ids[kind] = id
  W.resolve()
  return true
end
function W.get(kind)
  kind = trim(kind):lower()
  if not kinds[kind] then return '' end
  W.resolve()
  return W.ids[kind] or ''
end
function W.wield_cmd(kind)
  local id = W.get(kind)
  return id ~= '' and ('wield ' .. kind .. id) or nil
end
function W.send_wields()
  local sent = false
  for _, kind in ipairs({'shield', 'staff'}) do
    local cmd = W.wield_cmd(kind)
    if cmd then
      if type(Yso.send) == 'function' then Yso.send(cmd)
      elseif type(send) == 'function' then send(cmd, false) end
      sent = true
    end
  end
  return sent
end

-- Parse only requested equipment/inventory listings, ending at a game prompt.
local function stop_timeout()
  if W.timer and type(killTimer) == 'function' then killTimer(W.timer) end
  W.timer = nil
end
local function arm(command)
  stop_timeout()
  W.listing = { command = command, rows = {}, started = false, section = '' }
  if type(tempTimer) == 'function' then
    local listing = W.listing
    W.timer = tempTimer(8, function()
      if W.listing ~= listing then return end
      W.listing = nil; W.pending_listings = {}; W.timer = nil; W.refreshing = false
    end)
  end
end
local function query(command)
  arm(command)
  W.issuing_query = true
  if type(send) == 'function' then send(command, false) end
  W.issuing_query = false
end
function W.capture_line(raw)
  local listing = W.listing
  if not listing then return end
  local line = tostring(raw or ''):gsub('\27%[[%d;]*m', '')
  if line:match('^%s*You are holding:') then listing.started = true; return end
  if not listing.started then return end
  if line:match('^%s*You are wearing:') then listing.section = 'wearing'; return end
  if line:match('^%s*Wielded:') then listing.section = 'wielded'; return end
  if line:match('^%s*[%a ]+:') and not line:match('^%s*[LR][a-z]+ hand:') then listing.section = 'misc' end
  if listing.section == 'wearing' then return end
  local ref, name = line:match('^%s*[LR][a-z]+ hand:%s*(%a+%d+)%s+(.+)$')
  if not ref then ref, name = line:match('^%s*(%a+%d+)%s+(.+)$') end
  local id = ref and digits(ref)
  if not id then return end
  local attrs = line:find('Left hand:', 1, true) and 'l' or line:find('Right hand:', 1, true) and 'L' or ''
  local item = {id=id, name=name, attrib=attrs}
  if classify(item) then listing.rows[id] = item end
end
function W.finish_listing()
  local listing = W.listing
  if not listing or not listing.started then return end
  stop_timeout(); W.listing = nil
  local filter = listing.command:match('^ii (%a+)$')
  if filter then
    for id, item in pairs(W.inventory) do if classify(item) == filter then W.inventory[id] = nil end end
  else
    -- eq confirms wield state, but does not prove an unwielded item absent.
    for _, item in pairs(W.inventory) do item.attrib = tostring(item.attrib or ''):gsub('[lL]', '') end
  end
  for id, item in pairs(listing.rows) do W.inventory[id] = item end
  W.resolve()
  if #W.pending_listings > 0 then
    arm(table.remove(W.pending_listings, 1))
  elseif W.refreshing then
    if listing.command == 'eq' and W.get('staff') == '' then query('ii staff')
    elseif listing.command ~= 'ii shield' and W.get('shield') == '' then query('ii shield')
    else W.refreshing = false end
  end
end
function W.refresh()
  if not (Yso.session and Yso.session.is_ready()) then return false, 'not_authenticated' end
  if W.listing then return false end
  W.refreshing = true
  if type(sendGMCP) == 'function' then sendGMCP('Char.Items.Inv ""') end
  query('eq')
  return true
end
function W.clear_session()
  W.authenticated = false
  stop_timeout(); W.listing = nil; W.refreshing = false
  W.inventory = {}; W.ids = {staff='', shield=''}; W.pending_listings = {}
  magistaff = ''; magishield = ''
end
local function bind(event, fn)
  if type(registerAnonymousEventHandler) ~= 'function' then return end
  if W.handlers[event] and type(killAnonymousEventHandler) == 'function' then killAnonymousEventHandler(W.handlers[event]) end
  W.handlers[event] = registerAnonymousEventHandler(event, fn)
end
for _, action in ipairs({'List', 'Add', 'Update', 'Remove'}) do
  local kind = action
  bind('gmcp.Char.Items.' .. kind, function()
    local items = gmcp and gmcp.Char and gmcp.Char.Items
    W.capture_items(items and items[kind], kind)
  end)
end
if W.prompt_trigger and type(killTrigger) == 'function' then killTrigger(W.prompt_trigger) end
if type(tempPromptTrigger) == 'function' then W.prompt_trigger = tempPromptTrigger(W.finish_listing) end
bind('sysDataSendRequest', function(_, command)
  command = trim(command):lower()
  if command == 'eq' or command == 'ii staff' or command == 'ii shield' then
    if W.issuing_query then return end
    if W.listing then W.pending_listings[#W.pending_listings+1] = command
    else arm(command) end
  end
end)
-- Migrate old local session handlers on reload; the shared service owns login.
for _, event in ipairs({'sysConnectionEvent','sysDisconnectionEvent','gmcp.Char.Status','gmcp.Char.Vitals'}) do
  if W.handlers[event] and type(killAnonymousEventHandler) == 'function' then killAnonymousEventHandler(W.handlers[event]) end
  W.handlers[event] = nil
end
if Yso.session and Yso.session.is_ready() then
  stop_timeout(); W.listing = nil; W.refreshing = false; W.pending_listings = {}
else
  W.clear_session()
end
if Yso.session and type(Yso.session.subscribe) == 'function' then
  Yso.session.subscribe('magi.weapons', function() W.authenticated=true; W.refresh() end, W.clear_session)
end
if W.line_trigger and type(killTrigger) == 'function' then killTrigger(W.line_trigger) end
if type(tempRegexTrigger) == 'function' then
  W.line_trigger = tempRegexTrigger('^.*$', function() W.capture_line(type(getCurrentLine) == 'function' and getCurrentLine() or (matches and matches[1])) end)
end
W.resolve()
return W
