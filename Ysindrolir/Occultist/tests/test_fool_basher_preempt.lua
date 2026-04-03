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
  local timer_id = 0
  local trigger_id = 0
  local event_id = 0
  local events = {}

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
    timer_id = timer_id + 1
    timers[timer_id] = { secs = secs, fn = fn }
    return timer_id
  end
  _G.killTimer = function(id)
    timers[id] = nil
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
    return opts.now or 1000
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
      min_affs_hunt = 2,
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
      Vitals = {},
    },
  }

  _G.Yso = {
    queue = {
      addclearfull = function(qtype, payload)
        op("queue:addclearfull:" .. tostring(qtype) .. ":" .. tostring(payload))
        return opts.queue_ok ~= false
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
  }
  _G.yso = _G.Yso

  dofile(FOOL_PATH)

  return {
    ops = ops,
    timers = timers,
    triggers = triggers,
    events = events,
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
  }
end

print("=== Test 1: manual Fool hard-preempts basher after eligibility checks ===")
do
  local world = make_world({
    affs = { brokenleftarm = true, clumsiness = true },
  })

  local used = Legacy.FoolSelfCleanse("manual")
  assert_true("1a: manual use returns true", used)
  assert_ops("1b: clear freestand then queue fool", world.ops, {
    "send:cq freestand",
    "queue:addclearfull:bal:fling fool at me",
  })
  assert_eq("1c: basher queued reset", Legacy.Settings.Basher.queued, false)
  assert_true("1d: basher hold active", world.F.blocks_basher())
end

print("\n=== Test 2: prone blocks Fool before any basher interference ===")
do
  local world = make_world({
    affs = { prone = true, brokenleftarm = true, clumsiness = true },
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
    affs = { brokenleftarm = true, clumsiness = true },
  })

  world.F.on_vitals()
  assert_true("3a: auto path clears and queues", #world.ops == 2)
  assert_true("3b: auto path arms hold", world.F.blocks_basher())
  world.run_trigger(Yso._trig.fool_success)
  assert_false("3c: success line releases hold", world.F.blocks_basher())
end

print("\n=== Test 4: diagnose snapshot path arms hold and timeout releases ===")
do
  local world = make_world({
    affs = { brokenleftarm = true, clumsiness = true },
  })

  world.F.mark_diag_pending()
  world.run_trigger(Yso._trig.fool_eq)
  assert_true("4a: diagnose path arms hold", world.F.blocks_basher())
  assert_true("4b: hold timer captured", world.F.state.basher_hold_timer ~= nil)
  world.run_timer(world.F.state.basher_hold_timer)
  assert_false("4c: timeout releases hold", world.F.blocks_basher())
end

io.write(string.format("PASS: %d\n", pass_count))
if fail_count > 0 then
  io.stderr:write(string.format("FAILURES: %d\n", fail_count))
  os.exit(1)
end
