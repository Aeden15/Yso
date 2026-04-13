-- Auto-exported from Mudlet package script: Yso Occultist companions
-- DO NOT EDIT IN XML; edit this file instead.

--========================================================--
-- Yso/Combat/occultist/companions.lua
--  * Shared Occultist companion-control helper.
--  * Canonical automation commands:
--      order loyals kill <target>
--      order loyals passive
--  * Companion control is free-lane only.
--========================================================--

Yso = Yso or {}
Yso.occ = Yso.occ or {}

local C = Yso.occ.companions or {}
Yso.occ.companions = C

C.cfg = C.cfg or {
  recall_timeout_s = 6.0,
}

C.state = C.state or {
  recovering = false,
  recall_pending = false,
  last_target = "",
  last_failure = "",
  last_failure_at = 0,
  last_recall_at = 0,
  last_recovery = "",
  last_recovery_at = 0,
  invalidated_at = 0,
  invalidated_by = "",
  recall_timer_id = nil,
}

C._tr = C._tr or {}
C._hooks_installed = (C._hooks_installed == true)

local function _trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _lc(s)
  return _trim(s):lower()
end

local function _now()
  if Yso and Yso.util and type(Yso.util.now) == "function" then
    local ok, v = pcall(Yso.util.now)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if type(getEpoch) == "function" then
    local v = tonumber(getEpoch()) or os.time()
    if v > 1e12 then v = v / 1000 end
    return v
  end
  return os.time()
end

local function _debug_on()
  if C.cfg and C.cfg.debug == true then return true end
  if Yso and Yso.queue and Yso.queue.cfg and Yso.queue.cfg.debug == true then return true end
  return false
end

local function _dbg(msg)
  if not _debug_on() then return end
  local line = string.format("<dim_grey>[Yso:Occ:companions] <reset>%s", tostring(msg))
  if Yso and Yso.util and type(Yso.util.cecho_line) == "function" then
    Yso.util.cecho_line(line)
  elseif type(cecho) == "function" then
    cecho(line .. "\n")
  end
end

local function _kill_trigger(id)
  if id and type(killTrigger) == "function" then
    pcall(killTrigger, id)
  end
end

local function _clear_recall_timer()
  local st = C.state
  if st.recall_timer_id and type(killTimer) == "function" then
    pcall(killTimer, st.recall_timer_id)
  end
  st.recall_timer_id = nil
end

local function _set_loyals_hostile(v, tgt)
  local hostile = (v == true)
  tgt = _trim(tgt)
  if type(Yso.set_loyals_attack) == "function" then
    pcall(Yso.set_loyals_attack, hostile, tgt)
  elseif Yso and Yso.state then
    Yso.state.loyals_hostile = hostile
    if hostile and tgt ~= "" then
      Yso.state.loyals_target = tgt
    elseif not hostile then
      Yso.state.loyals_target = nil
    end
  end
  rawset(_G, "loyals_attack", hostile)
end

local function _emit_free(cmds, reason, target)
  local payload = { free = cmds, target = _trim(target) }

  if type(Yso.emit) == "function" then
    local ok, sent = pcall(Yso.emit, payload, {
      reason = reason or "occ.companions",
      kind = "offense",
      commit = true,
      target = _trim(target),
    })
    return ok == true and sent == true
  end

  if Yso and Yso.queue and type(Yso.queue.emit) == "function" then
    local ok, sent = pcall(Yso.queue.emit, payload, {
      reason = reason or "occ.companions",
      kind = "offense",
      commit = true,
      target = _trim(target),
    })
    return ok == true and sent == true
  end

  if type(send) == "function" then
    local sep = (Yso and (Yso.sep or (Yso.cfg and (Yso.cfg.cmd_sep or Yso.cfg.pipe_sep)))) or "&&"
    if type(cmds) == "string" then
      cmds = { cmds }
    end
    local out = {}
    for i = 1, #(cmds or {}) do
      local cmd = _trim(cmds[i])
      if cmd ~= "" then out[#out + 1] = cmd end
    end
    if #out == 0 then return false end
    local body = table.concat(out, sep)
    local ok, sent = pcall(send, body)
    return ok == true and sent ~= false
  end

  return false
end

function C.is_route_active()
  local M = Yso and Yso.mode or nil
  if type(M) == "table" and type(M.route_loop_active) == "function" then
    local routes = { "oc_aff", "occ_aff", "aff", "group_aff", "party_aff", "group_damage" }
    for i = 1, #routes do
      local ok, v = pcall(M.route_loop_active, routes[i])
      if ok and v == true then return true end
    end
  end

  if type(M) == "table" and type(M.active_route_id) == "function" then
    local ok, rid = pcall(M.active_route_id)
    rid = ok and _lc(rid) or ""
    if rid == "oc_aff" or rid == "occ_aff" or rid == "aff" or rid == "group_aff" or rid == "party_aff" or rid == "group_damage" then
      return true
    end
  end

  local Off = Yso and Yso.off and Yso.off.oc or nil
  if type(Off) == "table" then
    local a = Off.oc_aff or Off.occ_aff
    if type(a) == "table" and type(a.state) == "table" and a.state.loop_enabled == true then return true end
    local p = Off.group_aff or Off.party_aff
    if type(p) == "table" and type(p.state) == "table" and p.state.loop_enabled == true then return true end
    local g = Off.group_damage
    if type(g) == "table" and type(g.state) == "table" and g.state.loop_enabled == true then return true end
  end

  return false
end

function C.is_active_for(tgt)
  tgt = _trim(tgt)
  if tgt ~= "" and type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack, tgt)
    if ok and v == true then return true end
  elseif tgt == "" and type(Yso.loyals_attack) == "function" then
    local ok, v = pcall(Yso.loyals_attack)
    if ok and v == true then return true end
  end

  local st = Yso and Yso.state or nil
  if type(st) == "table" then
    local hostile = (st.loyals_hostile == true)
    if not hostile then return false end
    if tgt == "" then return true end
    local keyed = _lc(st.loyals_target)
    return keyed == "" or keyed == _lc(tgt)
  end

  return false
end

function C.is_any_active()
  return C.is_active_for("")
end

function C.can_order()
  local st = (type(C.state) == "table") and C.state or {}
  return st.recovering ~= true
end

function C.mark_recovering(reason)
  reason = _trim(reason)
  local st = C.state
  st.recovering = true
  st.last_failure = reason
  st.last_failure_at = _now()
  _dbg("companion order suppressed: recovering")
  return true
end

function C.reset_recovery(reason)
  local st = C.state
  _clear_recall_timer()
  st.recovering = false
  st.recall_pending = false
  st.last_recovery = _trim(reason)
  st.last_recovery_at = _now()
  return true
end

function C.note_recovery(kind, line)
  kind = _trim(kind)
  local st = (type(C.state) == "table") and C.state or nil
  if st and (st.recovering == true or st.recall_pending == true) then
    C.reset_recovery(kind ~= "" and kind or "recovered")
    _dbg("companion recovery: " .. tostring(kind ~= "" and kind or line or "unknown"))
  end
  return true
end

function C.note_failure(kind, line)
  if not C.is_route_active() then return false, "inactive" end

  kind = _trim(kind)
  C.mark_recovering(kind ~= "" and kind or "failure")
  _set_loyals_hostile(false)

  local st = C.state
  if st.recall_pending == true then
    _dbg("call entities skipped: recovery already pending")
    return false, "recall_pending"
  end

  st.recall_pending = true
  st.last_failure_at = _now()

  local sent = _emit_free({ "call entities" }, "occ.companions.recall", st.last_target)
  if sent then
    st.last_recall_at = _now()
    _dbg("call entities fired: one-shot recovery")
  end

  _clear_recall_timer()
  local timeout_s = tonumber(C.cfg.recall_timeout_s or 6.0) or 6.0
  if timeout_s < 1.0 then timeout_s = 1.0 end
  if type(tempTimer) == "function" then
    st.recall_timer_id = tempTimer(timeout_s, function()
      C.reset_recovery("timer_fallback")
    end)
  end

  return sent, (sent and "recall_sent" or "recall_emit_failed")
end

function C.note_order_sent(cmd, target)
  cmd = _lc(cmd)
  target = _trim(target)
  if cmd == "" then return false end

  if cmd == "order loyals passive" then
    _set_loyals_hostile(false)
    C.note_recovery("passive_sent")
    return true
  end

  local t = cmd:match("^order%s+loyals%s+kill%s+(.+)$")
  if t and t ~= "" then
    t = _trim(target ~= "" and target or t)
    C.state.last_target = t
    _set_loyals_hostile(true, t)
    if C.state.recovering == true or C.state.recall_pending == true then
      C.note_recovery("loyals_sent")
    end
    return true
  end

  return false
end

function C.invalidate(kind, meta)
  kind = _trim(kind)
  C.state.invalidated_at = _now()
  C.state.invalidated_by = kind ~= "" and kind or "unknown"
  _set_loyals_hostile(false)
  if type(raiseEvent) == "function" then
    raiseEvent("yso.occ.companions.invalidated", C.state.invalidated_by, meta)
  end
  _dbg("companion invalidated: " .. tostring(C.state.invalidated_by))
  return true
end

function C.kill(target, opts)
  opts = type(opts) == "table" and opts or {}
  target = _trim(target)
  if target == "" then return nil, "no_target" end

  if C.can_order() ~= true and opts.force ~= true then
    _dbg("companion order suppressed: recovering")
    return nil, "recovering"
  end

  C.state.last_target = target
  local cmd = string.format("order loyals kill %s", target)
  local out = {}
  if opts.include_stand == true then out[#out + 1] = "stand" end
  out[#out + 1] = cmd

  if opts.emit == true then
    local ok = _emit_free(out, "occ.companions.kill", target)
    if ok then C.note_order_sent(cmd, target) end
    if not ok then return false, "emit_failed" end
    return true, cmd
  end

  return out, "team_coordination"
end

function C.passive(opts)
  opts = type(opts) == "table" and opts or {}
  local target = _trim(opts.target or C.state.last_target)
  local cmd = "order loyals passive"

  if opts.emit == true then
    local ok = _emit_free({ cmd }, "occ.companions.passive", target)
    if ok then C.note_order_sent(cmd, target) end
    if not ok then return false, "emit_failed" end
    return true, cmd
  end

  return cmd, "route_off_cleanup"
end

function C.install_hooks()
  if C._hooks_installed == true then return true end
  if type(tempRegexTrigger) ~= "function" then return false end

  _kill_trigger(C._tr.no_loyal_single)
  C._tr.no_loyal_single = tempRegexTrigger(
    [[^You have no loyal companion here\.$]],
    function() C.note_failure("no_loyal", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.no_loyal_plural)
  C._tr.no_loyal_plural = tempRegexTrigger(
    [[^You have no loyal companions here\.$]],
    function() C.note_failure("no_loyal", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.no_entourage)
  C._tr.no_entourage = tempRegexTrigger(
    [[^You have no entourage\.$]],
    function() C.note_failure("no_entourage", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.no_beings)
  C._tr.no_beings = tempRegexTrigger(
    [[^There are no beings in your entourage\.$]],
    function() C.note_failure("no_entourage", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.recall_ready)
  C._tr.recall_ready = tempRegexTrigger(
    [[^You may call your pacted minions once more\.$]],
    function() C.note_recovery("recall_ready", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.tumble)
  C._tr.tumble = tempRegexTrigger(
    [[^You tumble .+\.$]],
    function() C.invalidate("tumble:text", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.starburst)
  C._tr.starburst = tempRegexTrigger(
    [[^[Yy]our starburst tattoo .+$]],
    function() C.invalidate("starburst:text", line or getCurrentLine()) end
  )

  _kill_trigger(C._tr.astralform)
  C._tr.astralform = tempRegexTrigger(
    [[^[Yy]ou .*astralform.*$]],
    function() C.invalidate("astralform:text", line or getCurrentLine()) end
  )

  C._hooks_installed = true
  return true
end

C.install_hooks()

return C
