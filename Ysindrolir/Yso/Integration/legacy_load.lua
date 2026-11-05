function Legacy_Load()
  local S = Yso and Yso.session
  if not (S and type(S.is_ready)=='function' and S.is_ready()) then return false, 'not_authenticated' end
    if not (gmcp and gmcp.Char and gmcp.Room and gmcp.Char.Status
        and type(gmcp.Char.Status.name) == "string") then
        S.later('legacy.load.retry', 2, function() Legacy_Load() end, true)
      return
    end
  if io.exists(getMudletHomeDir().."/Legacy/Legacy.lua") then
    Legacy = Legacy or {}
    Legacy[gmcp.Char.Status.name] = Legacy[gmcp.Char.Status.name] or {}
    Legacy.Rift = Legacy.Rift or {}
    Legacy.CT = Legacy.CT or {}
    Legacy.CT.timers = {}
    Legacy.Curing = Legacy.Curing or {}
    Legacy.NDB = Legacy.NDB or {}
    Legacy.NDB.Hidden = {}
    Legacy.Runes = Legacy.Runes or {}
    Legacy.Runes.smudgelist = Legacy.Runes.smudgelist or {}
    Legacy.Room = Legacy.Room or {}
    Legacy.Q = Legacy.Q or {}
    Legacy.Curing.Prios = Legacy.Curing.Prios or {}
    Legacy.Curing.Affs = {}
    Legacy.Curing.Defs = Legacy.Curing.Defs or {}
    Legacy.Curing.Defs.tracking = {}
    Legacy.Curing.Defs.current = {}
    Legacy.CT.Enemies = Legacy.CT.Enemies or {}
    Legacy.CT.StaticAllies = Legacy.CT.StaticAllies or {}
    Legacy.CT.StaticEnemies = Legacy.CT.StaticEnemies or {}
    Legacy.CT.timers = {}
    --NDB
    Legacy.NDB.db = Legacy.NDB.db or {}
    Legacy.NDB.Enemies = Legacy.NDB.Enemies or {}
    Legacy.NDB.qwhom = Legacy.NDB.qwhom or {}
    Legacy.Settings = Legacy.Settings or {}
    Legacy.Settings.Curing = Legacy.Settings.Curing or {}
    Legacy.Settings.Curing.SS = Legacy.Settings.Curing.SS or {}
    Legacy.Settings.NDB = Legacy.Settings.NDB or {}
    lfs.mkdir(getMudletHomeDir().. "/Legacy")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/NDB")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/NDB/Characters")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/Downloads")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/ClassTrack")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/Fight Logs")

    --Curing
    Legacy.Settings.Curing.precacheCount = 1 -- number of curatives to remove on eat
    Legacy.Settings.Curing.SS.Settings = Legacy.Settings.Curing.SS.Settings or {}
    Legacy.Curing.Lust = Legacy.Curing.Lust or {}
    Legacy.Curing.Defs.currentset = Legacy.Curing.Defs.currentset or "legacy"
    tempTimer(6,[[cecho("\n<white>[<gold>Legacy<white>]:<white> Welcome back "..gmcp.Char.Status.name.."!")]])
    table.load(getMudletHomeDir().."/Legacy/Legacy.lua", Legacy)
    Legacy_EnsureState()
    Legacy.Settings.NDB.tempHL = {}
    raiseEvent("LegacyLoaded")
  else
    Legacy = Legacy or {}
    Legacy.Vinfo = {Version = "", msg = "", link = ""}
    Legacy.Version = "0.8"
    Legacy.Extras = Legacy.Extras or {}
    Legacy[gmcp.Char.Status.name] = Legacy[gmcp.Char.Status.name] or {}
    Legacy.Rift = Legacy.Rift or {}
    Legacy.CT = Legacy.CT or {}
    Legacy.Curing = Legacy.Curing or {}
    Legacy.NDB = Legacy.NDB or {}
    Legacy.NDB.Hidden = {}
    Legacy.Runes = Legacy.Runes or {}
    Legacy.Runes.smudgelist = Legacy.Runes.smudgelist or {}
    Legacy.Room = Legacy.Room or {}
    Legacy.Q = Legacy.Q or {}
    Legacy.Curing.Prios = Legacy.Curing.Prios or {}
    Legacy.Curing.Affs = {}
    Legacy.Curing.Defs = Legacy.Curing.Defs or {}
    Legacy.CT.Enemies = Legacy.CT.Enemies or {}
    Legacy.CT.StaticAllies = Legacy.CT.StaticAllies or {}
    Legacy.CT.StaticEnemies = Legacy.CT.StaticEnemies or {}
    Legacy.CT.timers = {}
    --NDB
    Legacy.NDB.db = Legacy.NDB.db or {}
    Legacy.NDB.Enemies = Legacy.NDB.Enemies or {}
    Legacy.NDB.qwhom = Legacy.NDB.qwhom or {}
    Legacy.Curing.Defs.currentset = Legacy.Curing.Defs.currentset or "legacy"
    Legacy.Curing.Defs.tracking = {}
    Legacy.Curing.Defs.current = {}
    Legacy.Settings = Legacy.Settings or {}
    Legacy.Settings.Curing = Legacy.Settings.Curing or {}
    Legacy.Settings.Curing.SS = Legacy.Settings.Curing.SS or {}
    Legacy.Settings.NDB = Legacy.Settings.NDB or {}
    --Curing
    Legacy.Settings.Curing.precacheCount = 1 -- number of curatives to remove on eat
    Legacy.Settings.Curing.SS.Settings = Legacy.Settings.Curing.SS.Settings or {}
    Legacy.Curing.Lust = Legacy.Curing.Lust or {}
    lfs.mkdir(getMudletHomeDir().. "/Legacy")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/NDB")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/NDB/Characters")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/Downloads")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/ClassTrack")
    lfs.mkdir(getMudletHomeDir().. "/Legacy/Fight Logs")
    tempTimer(5, [[cecho("\n<red>Failed to Load Legacy Settings.")]])
    tempTimer(6 ,[[cecho("\n<green>Legacy Files Created At: \n<white>"..getMudletHomeDir().."/Legacy")]])
    table.save(getMudletHomeDir().."/Legacy/Legacy.lua", Legacy)
    sendAll("Curingset new legacy", "curingset switch legacy")
    Legacy_EnsureState()
    raiseEvent("LegacyLoaded")
    Download("Fresh")
  end
end

Legacy = Legacy or {}
if Legacy._login_handler and type(killAnonymousEventHandler)=='function' then
  killAnonymousEventHandler(Legacy._login_handler)
end
Legacy._login_handler = registerAnonymousEventHandler('LoggedIn', 'Legacy_Load')


