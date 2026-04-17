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
local FOOL_PATH = join_path(SCRIPT_DIR, "..", "modules", "Yso", "xml", "fool_logic.lua")

local pass_count = 0
local fail_count = 0

local function fail(label, detail)
  fail_count = fail_count + 1
  io.stderr:write(string.format("FAIL: %s%s\n", label, detail and (" - " .. detail) or ""))
end

local function pass()
  pass_count = pass_count + 1
end

local function assert_eq(label, got, expected)
  if got ~= expected then
    fail(label, string.format("expected %s, got %s", tostring(expected), tostring(got)))
    return
  end
  pass()
end

local function assert_true(label, got)
  if got ~= true then
    fail(label, string.format("expected true, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_false(label, got)
  if got ~= false then
    fail(label, string.format("expected false, got %s", tostring(got)))
    return
  end
  pass()
end

local function assert_count(label, got, expected)
  if #got ~= expected then
    fail(label, string.format("expected %d ops, got %d", expected, #got))
    return
  end
  pass()
end

local function assert_ops(label, got, expected)
  if #got ~= #expected then
    fail(label, string.format("expected %d ops, got %d", #expected, #got))
    return
  end
  for i = 1, #expected do
    if got[i] ~= expected[i] then
      fail(label, string.format("op %d expected %s, got %s", i, tostring(expected[i]), tostring(got[i])))
      return
    end
  end
  pass()
end

local function make_world(opts)
  opts = opts or {}

  local ops = {}
  local timers = {}
  local triggers = {}
  local owned = {}
  local timer_id = 0
  local trigger_id = 0
  local event_id = 0
  local events = {}
  local now = tonumber(opts.now) or 1000
  local bal_ready = (opts.bal_ready ~= false)

  local function op(x)
    ops[#ops + 1] = x
  end

  _G.print = function() end
  _G.echo = function() end
  _G.cecho = function() end
  _G.send = function(cmd, show)
    op("send:" .. tostring(cmd))
    return true
  end
  _G.tempTimer = function(secs, fn)
    if opts.no_temp_timer == true then
      return nil
    end
    timer_id = timer_id + 1
    timers[timer_id] = { secs = secs, fn = fn }
    return timer_id
  end
  _G.killTimer = function(id)
    if opts.kill_timer_error == true then
      error("killTimer unavailable")
    end
    if opts.kill_timer_returns_false == true then
      return false
    end
    timers[id] = nil
    return true
  end
  _G.tempRegexTrigger = function(pattern, fn)
    trigger_id = trigger_id + 1
    triggers[trigger_id] = { pattern = pattern, fn = fn }
    return trigger_id
  end
  _G.killTrigger = function(id)
    triggers[id] = nil
  end
  _G.tempAlias = function(pattern, fn)
    trigger_id = trigger_id + 1
    triggers[trigger_id] = { pattern = pattern, fn = fn }
    return trigger_id
  end
  _G.killAlias = function(id)
    triggers[id] = nil
  end
  _G.registerAnonymousEventHandler = function(name, fn)
    event_id = event_id + 1
    events[event_id] = { name = name, fn = fn }
    return event_id
  end
  _G.killAnonymousEventHandler = function(id)
    events[id] = nil
  end
  _G.getEpoch = function()
    return now
  end

  if opts.current_cureset ~= nil then
    _G.CurrentCureset = opts.current_cureset
  else
    _G.CurrentCureset = nil
  end

  _G.Legacy = {
    Curing = {
      Affs = opts.affs or {},
      ActiveServerSet = opts.cureset or "hunt",
    },
    Fool = {
      debug = opts.debug == true,
      queue_mode = "addclearfull",
      queue_type = "bal",
      min_affs_hunt = 4,
      min_affs_default = 6,
      ignore_blind_deaf = true,
    },
    Settings = {
      Basher = {
        status = opts.basher_active ~= false,
        queued = true,
      },
    },
  }

  _G.gmcp = {
    Char = {
      Status = {
        class = "Occultist",
      },
      Vitals = {
        bal = bal_ready,
        balance = bal_ready,
      },
    },
  }

  _G.Yso = {
    state = {
      bal_ready = function()
        return bal_ready == true
      end,
    },
    queue = {
      addclearfull = function(qtype, payload)
        op("queue:addclearfull:" .. tostring(qtype) .. ":" .. tostring(payload))
        local q = tostring(qtype or ""):lower()
        if q == "bal" or q == "b" or q == "bu" or q == "eqbal" then
          owned.bal = nil
        end
        return opts.queue_ok ~= false
      end,
      raw = function(body)
        op("queue:raw:" .. tostring(body))
        local upper = tostring(body or ""):upper()
        if upper:match("^CLEARQUEUE%s+") then
          local q = tostring(body:match("^CLEARQUEUE%s+(.+)$") or ""):lower()
          if q:find("bal", 1, true) or q == "eqbal" or q == "eb" or q == "be" then
            owned.bal = nil
          end
        end
        if opts.raw_ok == false then
          return false
        end
        return true
      end,
      set_owned = function(lane, rec)
        owned[tostring(lane or ""):lower()] = rec
        return true
      end,
      get_owned = function(lane)
        return owned[tostring(lane or ""):lower()]
      end,
      clear_owned = function(lane)
        owned[tostring(lane or ""):lower()] = nil
        return true
      end,
    },
    _trig = {},
    _eh = {},
    _alias = {},
    fool = {},
    mode = {
      is_hunt = function()
        return opts.is_hunt ~= false
      end,
    },
    self = {
      gmcp_aff_list_fresh = function()
        return opts.gmcp_list_fresh ~= false
      end,
    },
  }
  _G.yso = _G.Yso

  dofile(FOOL_PATH)

  return {
    ops = ops,
    timers = timers,
    triggers = triggers,
    events = events,
    owned = owned,
    F = Yso.fool,
    run_timer = function(id)
      if timers[id] and timers[id].fn then
        timers[id].fn()
      end
    end,
    run_trigger = function(id)
      if triggers[id] and triggers[id].fn then
        triggers[id].fn()
      end
    end,
    set_bal_ready = function(v)
      bal_ready = (v == true)
      gmcp.Char.Vitals.bal = bal_ready
      gmcp.Char.Vitals.balance = bal_ready
    end,
    set_now = function(v)
      now = tonumber(v) or now
    end,
    emit_event = function(name, ...)
      for _, row in pairs(events) do
        if row and row.name == name and type(row.fn) == "function" then
          row.fn(name, ...)
        end
      end
    end,
  }
end

print("=== Test 1: manual Fool hard-preempts basher after eligibility checks ===")
do
  local world = make_world({
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_true("1a: manual use returns true", used)
  assert_ops("1b: clear freestand then queue fool", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
  assert_eq("1c: basher queued reset", Legacy.Settings.Basher.queued, false)
  assert_true("1d: basher hold active", world.F.blocks_basher())
  assert_true("1e: Fool queue marked pending", world.F.state.pending == true)
end

print("\n=== Test 2: prone blocks Fool before any basher interference ===")
do
  local world = make_world({
    affs = { prone = true, brokenleftarm = true, clumsiness = true, nausea = true },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_false("2a: prone use returns false", used)
  assert_ops("2b: prone does not clear or queue", world.ops, {})
  assert_eq("2c: basher queued left untouched", Legacy.Settings.Basher.queued, true)
  assert_false("2d: basher hold remains off", world.F.blocks_basher())
end

print("\n=== Test 3: auto vitals path arms and releases basher hold ===")
do
  local world = make_world({
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  world.F.on_vitals()
  assert_true("3a: auto path clears and queues", #world.ops == 2)
  assert_true("3b: auto path arms hold", world.F.blocks_basher())
  world.run_trigger(Yso._trig.fool_success)
  assert_false("3c: success line releases hold", world.F.blocks_basher())
  assert_false("3d: success clears pending", world.F.state.pending)
end

print("\n=== Test 4: diagnose snapshot path arms hold and timeout releases ===")
do
  local world = make_world({
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  world.F.mark_diag_pending()
  world.run_trigger(Yso._trig.fool_eq)
  assert_true("4a: diagnose path arms hold", world.F.blocks_basher())
  assert_true("4b: hold timer captured", world.F.state.basher_hold_timer ~= nil)
  world.run_timer(world.F.state.basher_hold_timer)
  assert_false("4c: timeout releases hold", world.F.blocks_basher())
end

print("\n=== Test 5: pending Fool cancels when hunt threshold drops before fire ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true }
  local world = make_world({
    affs = affs,
  })

  assert_true("5a: manual use queues Fool", Legacy.FoolSelfCleanse("manual"))
  assert_true("5b: pending flag armed", world.F.state.pending == true)

  affs.nausea = nil
  world.F.on_vitals()

  assert_ops("5c: stale pending Fool clears its queue", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
    "queue:raw:CLEARQUEUE bal",
  })
  assert_false("5d: stale pending clears hold", world.F.blocks_basher())
  assert_false("5e: stale pending cleared", world.F.state.pending)
  assert_eq("5f: cooldown not consumed by cancel", world.F.state.last_used, 0)
  assert_eq("5g: owned bal cleared after cancel", world.owned.bal, nil)
end

print("\n=== Test 6: stale cancel fails closed if queue clear fails ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true }
  local world = make_world({
    affs = affs,
    raw_ok = false,
  })

  assert_true("6a: manual use queues Fool", Legacy.FoolSelfCleanse("manual"))
  affs.nausea = nil
  world.F.on_vitals()

  assert_true("6b: pending remains when clearqueue fails", world.F.state.pending == true)
  assert_true("6c: basher hold remains while pending clear failed", world.F.blocks_basher())
end

print("\n=== Test 7: stale cancel also fires on aff-change event (no vitals wait) ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true }
  local world = make_world({
    affs = affs,
  })

  assert_true("7a: manual use queues Fool", Legacy.FoolSelfCleanse("manual"))
  affs.nausea = nil
  world.emit_event("gmcp.Char.Afflictions.Remove")

  assert_ops("7b: aff-change event clears stale pending Fool queue", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
    "queue:raw:CLEARQUEUE bal",
  })
  assert_false("7c: stale pending cleared on aff-change event", world.F.state.pending)
  assert_false("7d: hold released on aff-change event", world.F.blocks_basher())
end

print("\n=== Test 8: ownership mismatch clears pending without CLEARQUEUE ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true }
  local world = make_world({
    affs = affs,
  })

  assert_true("8a: manual use queues Fool", Legacy.FoolSelfCleanse("manual"))
  world.owned.bal = {
    cmd = "cast bloodboil",
    note = "someone_else",
  }
  affs.nausea = nil
  world.F.on_vitals()

  assert_ops("8b: ownership mismatch avoids clearqueue", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
  assert_false("8c: mismatch clears pending marker", world.F.state.pending)
  assert_false("8d: mismatch releases hold", world.F.blocks_basher())
end

print("\n=== Test 9: attack-package retry stays suppressed until Fool releases ===")
do
  local world = make_world({
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  local function queue_attack_package(primary_cmd)
    if world.F.blocks_basher() then
      Legacy.Settings.Basher.queued = false
      return false
    end
    if primary_cmd and primary_cmd ~= "" then
      world.ops[#world.ops + 1] = "send:queue add freestand " .. tostring(primary_cmd)
    end
    world.ops[#world.ops + 1] = "send:queue add freestand basher"
    Legacy.Settings.Basher.queued = true
    return true
  end

  assert_true("9a: manual use queues Fool", Legacy.FoolSelfCleanse("manual"))
  assert_false("9b: hold suppresses attack-package requeue", queue_attack_package("command orb"))
  assert_eq("9c: basher queued stays false while suppressed", Legacy.Settings.Basher.queued, false)
  assert_count("9d: no extra ops while hold active", world.ops, 2)

  world.run_trigger(Yso._trig.fool_success)
  assert_true("9e: attack package resumes after success", queue_attack_package("command orb"))
  assert_eq("9f: basher queued becomes true after release", Legacy.Settings.Basher.queued, true)
  assert_ops("9g: resumed attack package queues paired work", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
    "send:queue add freestand command orb",
    "send:queue add freestand basher",
  })
end

print("\n=== Test 10: token drift still cancels pending Fool when cmd matches ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true }
  local world = make_world({
    affs = affs,
  })

  assert_true("10a: manual use queues Fool", Legacy.FoolSelfCleanse("manual"))
  world.owned.bal = {
    cmd = "fling fool at me",
    note = "rewritten_owner_note",
  }
  affs.nausea = nil
  world.F.on_vitals()

  assert_ops("10b: stale pending still clears queue with cmd-match fallback", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
    "queue:raw:CLEARQUEUE bal",
  })
  assert_false("10c: pending cleared after cmd-match fallback cancel", world.F.state.pending)
  assert_false("10d: hold released after cmd-match fallback cancel", world.F.blocks_basher())
end

print("\n=== Test 11: explicit cureset wins over hunt-mode fallback ===")
do
  local world = make_world({
    cureset = "legacy",
    is_hunt = true,
    bal_ready = false,
    affs = {
      clumsiness = true,
      nausea = true,
      stupidity = true,
      weariness = true,
      asthma = true,
      anorexia = true,
    },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_true("11a: explicit non-hunt cureset still allows non-hunt Fool behavior", used)
  assert_ops("11b: explicit cureset path still queues Fool", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
end

print("\n=== Test 12: hunt Fool requires at least 4 current afflictions ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true }
  local world = make_world({
    cureset = "hunt",
    affs = affs,
  })

  assert_false("12a: hunt with 3 affs does not use Fool", Legacy.FoolSelfCleanse("manual"))
  assert_ops("12b: no queue at 3 affs", world.ops, {})

  affs.stupidity = true
  assert_true("12c: hunt with 4 affs uses Fool", Legacy.FoolSelfCleanse("manual"))
  assert_ops("12d: queue appears only after reaching 4 affs", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
end

print("\n=== Test 13: hunt count is evaluated when balance is ready, not pre-armed ===")
do
  local affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true }
  local world = make_world({
    cureset = "hunt",
    bal_ready = false,
    affs = affs,
  })

  world.F.on_vitals()
  assert_ops("13a: no pre-arm while balance is down", world.ops, {})
  assert_false("13b: no pending queue while balance is down", world.F.state.pending == true)

  affs.stupidity = nil
  world.set_now(1002)
  world.set_bal_ready(true)
  world.F.on_vitals()

  assert_ops("13c: dropping below 4 before balance returns prevents Fool", world.ops, {})
  assert_false("13d: still no pending after balance-ready recheck", world.F.state.pending == true)
end

print("\n=== Test 14: hunt hard-fails block Fool (paralysis, prone, webbed, both arms) ===")
do
  local cases = {
    {
      name = "paralysis",
      affs = { paralysis = true, clumsiness = true, nausea = true, brokenleftarm = true },
    },
    {
      name = "prone",
      affs = { prone = true, clumsiness = true, nausea = true, brokenleftarm = true },
    },
    {
      name = "webbed",
      affs = { webbed = true, clumsiness = true, nausea = true, brokenleftarm = true },
    },
    {
      name = "both_arms_broken",
      affs = { brokenleftarm = true, brokenrightarm = true, clumsiness = true },
    },
  }

  for i = 1, #cases do
    local row = cases[i]
    local world = make_world({
      cureset = "hunt",
      affs = row.affs,
    })
    assert_false("14." .. tostring(i) .. ": hard fail blocks (" .. row.name .. ")", Legacy.FoolSelfCleanse("manual"))
    assert_ops("14." .. tostring(i) .. "b: no queue on hard fail (" .. row.name .. ")", world.ops, {})
  end
end

print("\n=== Test 15: one broken arm still allows hunt Fool and counts toward threshold ===")
do
  local world = make_world({
    cureset = "hunt",
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  assert_true("15a: one broken arm is not a hard fail", Legacy.FoolSelfCleanse("manual"))
  assert_ops("15b: one broken arm case still queues Fool at 4 affs", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
end

print("\n=== Test 16: CurrentCureset also beats hunt-mode fallback when ActiveServerSet is blank ===")
do
  local world = make_world({
    cureset = "",
    current_cureset = "legacy",
    is_hunt = true,
    bal_ready = false,
    affs = {
      clumsiness = true,
      nausea = true,
      stupidity = true,
      weariness = true,
      asthma = true,
      anorexia = true,
    },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_true("16a: CurrentCureset non-hunt selection is respected", used)
  assert_ops("16b: CurrentCureset path queues Fool without hunt bal gate", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
end

print("\n=== Test 17: tempTimer-missing fallback avoids stale pending or hold deadlock ===")
do
  local world = make_world({
    cureset = "hunt",
    no_temp_timer = true,
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  assert_true("17a: hunt Fool still queues with timer fallback", Legacy.FoolSelfCleanse("manual"))
  assert_ops("17b: queue still sent", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
  assert_false("17c: pending auto-cleared when tempTimer unavailable", world.F.state.pending == true)
  assert_false("17d: basher hold skipped when tempTimer unavailable", world.F.blocks_basher())
end

print("\n=== Test 18: stale basher timer callback cannot clear a newer hold generation ===")
do
  local world = make_world({
    cureset = "hunt",
    kill_timer_returns_false = true,
    affs = { brokenleftarm = true, clumsiness = true, nausea = true, stupidity = true },
  })

  assert_true("18a: first Fool queues", Legacy.FoolSelfCleanse("manual"))
  local stale_timer = world.F.state.basher_hold_timer
  assert_true("18b: first hold timer captured", stale_timer ~= nil)

  world.run_trigger(Yso._trig.fool_success)
  assert_false("18c: first success releases hold", world.F.blocks_basher())

  world.set_now(1040)
  assert_true("18d: second Fool queues", Legacy.FoolSelfCleanse("manual"))
  assert_true("18e: second hold is active", world.F.blocks_basher())

  world.run_timer(stale_timer)
  assert_true("18f: stale timer callback does not release new hold", world.F.blocks_basher())
end

print("\n=== Test 19: bash-mode stale gmcp-aff-list blocks manual Fool ===")
do
  local world = make_world({
    cureset = "legacy",
    gmcp_list_fresh = false,
    bal_ready = false,
    affs = {
      clumsiness = true,
      nausea = true,
      stupidity = true,
      weariness = true,
      asthma = true,
      anorexia = true,
    },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_false("19a: stale gmcp-aff-list blocks manual bash Fool", used)
  assert_ops("19b: stale guard blocks queue side-effects", world.ops, {})
end

print("\n=== Test 20: bash-mode stale gmcp-aff-list blocks auto Fool ===")
do
  local world = make_world({
    cureset = "legacy",
    gmcp_list_fresh = false,
    bal_ready = true,
    affs = {
      clumsiness = true,
      nausea = true,
      stupidity = true,
      weariness = true,
      asthma = true,
      anorexia = true,
    },
  })

  world.F.on_vitals()
  assert_ops("20a: auto path also blocked by stale guard", world.ops, {})
end

print("\n=== Test 21: bash-mode fresh gmcp-aff-list allows normal non-hunt evaluation ===")
do
  local world = make_world({
    cureset = "legacy",
    gmcp_list_fresh = true,
    bal_ready = false,
    affs = {
      clumsiness = true,
      nausea = true,
      stupidity = true,
      weariness = true,
      asthma = true,
      anorexia = true,
    },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_true("21a: fresh gmcp-aff-list allows manual path", used)
  assert_ops("21b: fresh path queues normally", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
