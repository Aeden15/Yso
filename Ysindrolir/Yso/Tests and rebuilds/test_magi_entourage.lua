-- Catches missing lifecycle orders and orders incorrectly gated by BAL/EQ.
local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*[/\\])')
local root = arg[1] or here .. '../../'
local runtime_root = arg[2] or root
local files = {'magi_focus.lua', 'Magi_duel_dam.lua', 'Magi_firestorm.lua', 'Magi_water_group.lua'}
local passed = 0
for _, file in ipairs(files) do
  local target, paused, magi, valid = 'Foe', false, true, true
  local sent, fail, eq = {}, false, false
  function cecho() end
  function echo() end
  function getEpoch() return 100000 end
  function send(command) sent[#sent + 1] = command; return true end
  gmcp = {Char={Status={class='Magi'},Vitals={eq='0',bal='0'}}}
  affstrack = {score={}}
  Yso = {off={magi={}},magi={},net={cfg={dry_run=false}},
    get_target=function() return target end,
    target_is_valid=function() return valid end,
    is_magi=function() return magi end,
    offense_paused=function() return paused end,
    state={eq_ready=function() return eq end},
    mode={is_combat=function() return true end,route_loop_active=function() return true end}}
  yso = Yso
  Yso.send = function(command)
    if fail then return false end
    if not Yso.net.cfg.dry_run then sent[#sent + 1] = command end
    return true
  end
  local RC = dofile(root .. 'Magi/magi_route_core.lua')
  dofile(root .. 'Magi/magi_dissonance.lua')
  local M = dofile(root .. 'Magi/' .. file) or Yso.off.magi.focus
  M.init()
  M.state.enabled, M.state.loop_enabled = true, true
  M.alias_loop_on_started({})
  assert(sent[1] == 'order entourage kill Foe', file .. ': start must order pets off BAL/EQ')
  local count = #sent
  M.attack_function()
  assert(#sent == count, file .. ': repeated target must not spam')
  target = 'Other'
  M.attack_function({preview=true})
  assert(#sent == count, file .. ': preview sends orders')
  M.attack_function()
  assert(sent[#sent] == 'order entourage kill Other', file .. ': target swap while EQ down')
  count = #sent
  paused = true; target = 'Third'; M.attack_function()
  assert(#sent == count, file .. ': pause must leave pets attacking')
  paused = false; M.attack_function()
  assert(sent[#sent] == 'order entourage kill Third', file .. ': resume reconciles target')
  count = #sent
  valid = false; target = 'Absent'; M.attack_function()
  assert(#sent == count, file .. ': invalid target gets kill order')
  valid = true; magi = false; M.attack_function()
  assert(#sent == count, file .. ': wrong class gets kill order')
  magi = true; target = ''; M.attack_function()
  assert(#sent == count, file .. ': empty target gets kill order')
  target = 'Retry'; fail = true; M.attack_function()
  assert(#sent == count, file .. ': failed dispatch unexpectedly sent')
  fail = false; M.attack_function()
  assert(sent[#sent] == 'order entourage kill Retry', file .. ': failed kill must retry')
  -- Stop while paused and without BAL/EQ; repeated callbacks must not duplicate.
  paused = true
  M.state.enabled, M.state.loop_enabled = false, false
  M.alias_loop_on_stopped({reason='manual',silent=true})
  assert(sent[#sent] == 'order entourage passive', file .. ': stop must pacify')
  count = #sent
  M.alias_loop_on_stopped({reason='exit',silent=true})
  assert(#sent == count, file .. ': cleanup must be idempotent')
  paused = false; M.state.enabled, M.state.loop_enabled = true, true
  target = 'Dry'; Yso.net.cfg.dry_run = true
  M.alias_loop_on_started({})
  assert(#sent == count, file .. ': dry run transmitted')
  Yso.net.cfg.dry_run = false; M.attack_function()
  assert(sent[#sent] == 'order entourage kill Dry', file .. ': dry run suppressed later live order')
  fail = true; M.alias_loop_on_stopped({reason='manual'})
  fail = false; M.alias_loop_on_stopped({reason='manual'})
  assert(sent[#sent] == 'order entourage passive', file .. ': failed passive must retry')
  -- Exercise real toggle/automatic-stop wiring, not just route callbacks.
  function tempTimer() return 1 end
  function killTimer() end
  Yso.class, Yso.mode = 'magi', {}
  dofile(runtime_root .. '/Yso/Combat/route_registry.lua')
  dofile(runtime_root .. '/Yso/xml/yso_modes.lua')
  Yso.mode.set_context('duel', 'test')
  local id = M.key or 'magi_focus'
  M.state.enabled, M.state.loop_enabled = false, false
  target = 'Toggle'; paused = false
  sent = {}
  assert(Yso.mode.toggle_route_loop(id, 'test'))
  assert(table.concat(sent, '\n'):find('order entourage kill Toggle', 1, true), file .. ': real toggle ON missed kill')
  assert(Yso.mode.toggle_route_loop(id, 'test'))
  assert(table.concat(sent, '\n'):find('order entourage passive', 1, true), file .. ': real toggle OFF missed passive')
  sent = {}
  assert(Yso.mode.toggle_route_loop(id, 'test'))
  target = ''
  Yso.mode.tick_route_loop(id)
  assert(not M.state.loop_enabled, file .. ': target loss did not stop route')
  assert(table.concat(sent, '\n'):find('order entourage passive', 1, true), file .. ': target loss missed passive')
  passed = passed + 1
end
print('PASS: entourage lifecycle, BAL/EQ independence, pause, preview, validation, dry-run and retries for ' .. passed .. ' Magi routes')
