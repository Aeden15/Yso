--========================================================--
-- Yso Bootstrap loader (Mudlet-native mode)
--  Bootstrap/path probing intentionally retired.
--========================================================--

Yso = Yso or {}
Yso.bootstrap = Yso.bootstrap or {}
Yso.bootstrap.mode = "mudlet_native"
_G.yso_bootstrap_done = true

-- #region agent log
local function _yso_dbg_log(hypothesisId, message, data)
  local payload = {
    sessionId = "f528bd",
    runId = "baseline",
    hypothesisId = hypothesisId,
    location = "yso_bootstrap_loader.lua",
    message = message,
    data = data or {},
    timestamp = os.time() * 1000,
  }
  local ok, json = pcall(yajl.to_string, payload)
  if not ok or type(json) ~= "string" then return end
  local f = io.open("C:/Users/shuji/OneDrive/Desktop/Yso systems/debug-f528bd.log", "a")
  if not f then return end
  f:write(json .. "\n")
  f:close()
end

_yso_dbg_log("H1", "bootstrap_loader_ran", {
  has_yso = type(Yso) == "table",
  has_mode_table = type(Yso.mode) == "table",
  has_toggle_route_loop = type(Yso.mode and Yso.mode.toggle_route_loop) == "function",
  has_toggle_route_alias = type(Yso.util and Yso.util.toggle_route_alias) == "function",
})
-- #endregion
