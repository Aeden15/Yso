--========================================================--
-- Yso Combat Route Interface (Common Contract)
--  • Canonical shared route contract for Occultist combat routes.
--  • Routes expose shared metadata/hooks for the alias-owned loop controller.
--  • Shared universal categories across future routes:
--      - defense_break
--      - anti_tumble
--  • Other strategic categories are route-local and may differ per route.
--  • All routes should expose the full lifecycle hook surface as callable stubs
--    even when the hook is currently a no-op.
--
-- Recommended override policy:
--  • Narrow global-only overrides.
--  • Shared route helpers may override route intent only for hard global conditions:
--      - reserved_burst
--      - target_invalid / target_slain
--      - route_off
--      - pause
--      - manual_suppression
--      - target_swap_bootstrap
--      - defense_break
--      - anti_tumble
--========================================================--

Yso = Yso or {}
Yso.Combat = Yso.Combat or {}
Yso.Combat.RouteInterface = Yso.Combat.RouteInterface or {}
local RI = Yso.Combat.RouteInterface

RI.VERSION = 1

RI.SHARED_CATEGORIES = RI.SHARED_CATEGORIES or {
  defense_break = true,
  anti_tumble   = true,
}

RI.DEFAULT_OVERRIDE_POLICY = RI.DEFAULT_OVERRIDE_POLICY or {
  mode = "narrow_global_only",
  allowed = {
    reserved_burst       = true,
    target_invalid       = true,
    target_slain         = true,
    route_off            = true,
    pause                = true,
    manual_suppression   = true,
    target_swap_bootstrap= true,
    defense_break        = true,
    anti_tumble          = true,
  },
}

RI.DEFAULT_HOOKS = RI.DEFAULT_HOOKS or {
  on_enter          = true,
  on_exit           = true,
  on_target_swap    = true,
  on_pause          = true,
  on_resume         = true,
  on_manual_success = true,
  on_send_result    = true,
  evaluate          = true,
  explain           = true,
}

local function _copy(tbl)
  local out = {}
  if type(tbl) ~= "table" then return out end
  for k, v in pairs(tbl) do out[k] = v end
  return out
end

local function _trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local _unpack = table.unpack or unpack

local function _noop() return nil end
local function _noop_evaluate() return {} end
local function _noop_explain() return {} end

function RI.normalize(spec)
  spec = type(spec) == "table" and spec or {}
  spec.interface_version = tonumber(spec.interface_version or RI.VERSION)
  spec.shared_categories = spec.shared_categories or { "defense_break", "anti_tumble" }
  spec.route_local_categories = spec.route_local_categories or {}
  spec.capabilities = spec.capabilities or {}
  spec.override_policy = spec.override_policy or _copy(RI.DEFAULT_OVERRIDE_POLICY)
  spec.lifecycle = spec.lifecycle or {
    on_enter = false,
    on_exit = false,
    on_target_swap = false,
    on_pause = false,
    on_resume = false,
    on_manual_success = false,
    on_send_result = false,
    evaluate = false,
    explain = false,
  }
  return spec
end

function RI.ensure_hooks(route, spec)
  route = type(route) == "table" and route or {}
  spec = RI.normalize(spec)

  local hook_impls = {
    on_enter = _noop,
    on_exit = _noop,
    on_target_swap = _noop,
    on_pause = _noop,
    on_resume = _noop,
    on_manual_success = _noop,
    on_send_result = _noop,
    evaluate = _noop_evaluate,
    explain = _noop_explain,
  }

  spec.lifecycle = spec.lifecycle or {}
  for hook, fn in pairs(hook_impls) do
    if type(route[hook]) ~= "function" then
      route[hook] = fn
    end
    spec.lifecycle[hook] = true
  end

  return route, spec
end

function RI.validate(spec)
  spec = RI.normalize(spec)
  local errs = {}
  if type(spec.id) ~= "string" or spec.id == "" then errs[#errs+1] = "missing route id" end
  if type(spec.shared_categories) ~= "table" then errs[#errs+1] = "shared_categories must be a table" end
  if type(spec.route_local_categories) ~= "table" then errs[#errs+1] = "route_local_categories must be a table" end
  if type(spec.capabilities) ~= "table" then errs[#errs+1] = "capabilities must be a table" end
  if type(spec.override_policy) ~= "table" then errs[#errs+1] = "override_policy must be a table" end
  return (#errs == 0), errs, spec
end

-- Build one route command from a command spec:
--   {
--     id = "freeze",
--     string = "cast freeze at %s",
--     slot = "freeze",
--     target_required = true,
--     format_target = true, -- pass target as first format arg
--     formatter = function(target, ...) return "..." end
--   }
function RI.command_from_spec(spec, target, args)
  spec = type(spec) == "table" and spec or {}
  local raw = _trim(spec.string)
  if raw == "" then return nil, "missing_string" end

  local list = {}
  if type(args) == "table" then
    for i = 1, #args do list[i] = args[i] end
  end

  local need_target = (spec.target_required ~= false)
  target = _trim(target)
  if need_target and target == "" then return nil, "no_target" end

  local cmd
  if type(spec.formatter) == "function" then
    local ok, built = pcall(spec.formatter, target, _unpack(list))
    if not ok then return nil, "formatter_error" end
    cmd = _trim(built)
  elseif spec.format_target == true then
    local ok, built = pcall(string.format, raw, target, _unpack(list))
    if not ok then return nil, "format_error" end
    cmd = _trim(built)
  elseif #list > 0 then
    local ok, built = pcall(string.format, raw, _unpack(list))
    if not ok then return nil, "format_error" end
    cmd = _trim(built)
  else
    cmd = raw
  end

  if cmd == "" then return nil, "empty_command" end
  return cmd, ""
end

-- Build + optional guard gate in one call.
-- Guard signature:
--   guard(slot, target, cmd, opts) -> ok:boolean, why:string
function RI.guard_and_build_command(opts)
  opts = type(opts) == "table" and opts or {}
  local spec = type(opts.spec) == "table" and opts.spec or {}
  local target = _trim(opts.target)
  local cmd, why = RI.command_from_spec(spec, target, opts.args)
  if not cmd then return false, tostring(why or "invalid_command"), "" end

  local guard = opts.guard
  if type(guard) == "function" then
    local slot = tostring(opts.slot or spec.slot or "")
    local ok, gwhy = guard(slot, target, cmd, opts)
    if ok ~= true then
      return false, tostring(gwhy or "guard_blocked"), cmd
    end
  end
  return true, "", cmd
end

return RI
