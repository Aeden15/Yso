Yso = Yso or {}
Yso.magi = Yso.magi or {}
Yso.magi.defs = Yso.magi.defs or {}

local M = Yso.magi.defs

M.state = M.state or {
  class_name = "",
}

local function _vitals()
  return (gmcp and gmcp.Char and gmcp.Char.Vitals) or {}
end

local function _status()
  return (gmcp and gmcp.Char and gmcp.Char.Status) or {}
end

function M.get_hp_percent()
  local v = _vitals()
  local hp = tonumber(v.hp)
  local maxhp = tonumber(v.maxhp)

  if not hp or not maxhp or maxhp <= 0 then
    return nil
  end

  return (hp / maxhp) * 100
end

function M.get_class()
  local s = _status()
  local cls = s.class or s.classname or M.state.class_name or ""
  return tostring(cls)
end

function M.is_magi()
  return M.get_class():lower() == "magi"
end

function M.set_class(classname)
  M.state.class_name = tostring(classname or "")
end
