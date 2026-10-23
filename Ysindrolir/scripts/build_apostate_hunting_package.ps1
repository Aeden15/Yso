[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$PackagePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'mudlet packages/Legacy Basher V2.1.xml'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$text=[IO.File]::ReadAllText($PackagePath)
$doc=[xml]$text
$newline=[regex]::Match($text,'\r\n|\n|\r').Value
if(-not $newline){$newline="`n"}
# XmlDocument normalizes parsed bodies to LF; source files and here-strings may
# use either checkout style. Embed every body using the destination's newlines.
function Escape([string]$value){[Security.SecurityElement]::Escape([regex]::Replace($value,'\r\n?|\n',$newline))}
function Entry([string]$tag,[string]$name){
 $pattern='(?s)<'+$tag+'\b[^>]*>\s*<name>'+[regex]::Escape($name)+'</name>.*?</'+$tag+'>'
 $hits=[regex]::Matches($script:text,$pattern)
 if($hits.Count -ne 1){throw ('Expected unique '+$tag+' '+$name)}
 return $hits[0]
}
function SetBody([string]$tag,[string]$name,[string]$body){
 $hit=Entry $tag $name
 # Quotes need no escaping inside element text; retain the original Legacy style.
 $escaped=(Escape $body).Replace('&quot;','"').Replace('&apos;',"'")
 $new=[regex]::Replace($hit.Value,'(?s)<script\s*/>|<script>.*?</script>',[Text.RegularExpressions.MatchEvaluator]{param($m) '<script>'+$escaped+'</script>'},1)
 $script:text=$script:text.Substring(0,$hit.Index)+$new+$script:text.Substring($hit.Index+$hit.Length)
}
$toggle=$doc.SelectSingleNode('//Alias[name="Hunting Toggle"]').script
if(-not $toggle.Contains('-- Apostate Soulstorm toggle adapter')){
 $needle='Legacy.Settings.Basher.totalDamage = {}'
 if(-not $toggle.Contains($needle)){throw 'Missing hunting toggle insertion point'}
 $toggle=$toggle.Replace($needle,$needle+"`n"+@'
-- Apostate Soulstorm toggle adapter: arm before status events can invoke Attack.
local soulstorm=Legacy.Basher.Soulstorm
if soulstorm then
  if Legacy.Settings.Basher.status == false then soulstorm.begin() else soulstorm.stop() end
end
'@)
 SetBody Alias 'Hunting Toggle' $toggle
}
$basher=$doc.SelectSingleNode('//Script[name="Basher"]').script
if(-not $basher.Contains('-- Apostate Soulstorm attack adapter')){
 $needle='      local isDenizenTarget = _attack_is_denizen_target(targetSet)'
 if(-not $basher.Contains($needle)){throw 'Missing basher attack insertion point'}
 $basher=$basher.Replace($needle,$needle+"`n"+@'
      -- Apostate Soulstorm attack adapter: precedes rage and ordinary basher queues.
      local soulstorm=Legacy.Basher.Soulstorm
      if soulstorm and soulstorm.before_attack(targetSet,targetInfo,isDenizenTarget) then return end
'@)
 $needle='    Legacy.Settings.Basher.status = false'
 if(-not $basher.Contains($needle)){throw 'Missing basher setup insertion point'}
 $basher=$basher.Replace($needle,$needle+"`n"+'    if Legacy.Basher.Soulstorm then Legacy.Basher.Soulstorm.stop() end')
 SetBody Script 'Basher' $basher
}
# Repair packages generated before saved-profile loading was covered by tests.
# Legacy_Load replaces nested tables, so install the runtime before using it.
if(-not $basher.Contains('LegacyBasher_InstallSoulstorm()')){
 $basher=$basher.Replace('function Basher_Setup()',@'
function Basher_Setup()
  if type(LegacyBasher_InstallSoulstorm) == "function" then LegacyBasher_InstallSoulstorm() end
'@)
}
$basher=$basher.Replace('if Legacy.Basher.Soulstorm then Legacy.Basher.Soulstorm.stop() end',
 'if Legacy.Basher.Soulstorm and type(Legacy.Basher.Soulstorm.stop) == "function" then Legacy.Basher.Soulstorm.stop() end')
$basher=$basher.Replace('if soulstorm and soulstorm.before_attack(targetSet,targetInfo,isDenizenTarget) then return end',
 'if soulstorm and type(soulstorm.before_attack) == "function" and soulstorm.before_attack(targetSet,targetInfo,isDenizenTarget) then return end')
if(-not $basher.Contains('-- A removal/slain pair belongs to the preceding output batch.')){
 $basher=$basher.Replace('  function Legacy.Basher.Attack()',@'
  function Legacy.Basher.Attack()
    -- A removal/slain pair belongs to the preceding output batch.
    -- Do not let a flee steal a later same-named target's slain line.
    Legacy.Settings.Basher._removedHuntTarget = nil
'@)
}
if(-not $basher.Contains('-- Reset transient targeting after saved settings load.')){
 $basher=$basher.Replace('    Legacy.Settings.Basher.status = false',@'
    -- Reset transient targeting after saved settings load.
    Legacy.Settings.Basher.currentTar = ""
    Legacy.Settings.Basher.possibleTargets = {}
    Legacy.Settings.Basher.desc = ""
    Legacy.Settings.Basher.queued = false
    Legacy.Settings.Basher.status = false
'@)
}
if(-not $basher.Contains('Legacy.Settings.Basher.mobRoom = nil')){
 $basher=$basher.Replace('    Legacy.Settings.Basher.currentTar = ""',"    Legacy.Settings.Basher.mobRoom = nil`n    Legacy.Settings.Basher.roomMobs = nil`n    Legacy.Settings.Basher.currentTar = `"`"")
}
if($basher -notmatch 'Legacy.Settings.Basher._removedHuntTarget = nil\r?\n    Legacy.Settings.Basher.mobRoom = nil'){
 $basher=$basher.Replace('    Legacy.Settings.Basher.mobRoom = nil',"    Legacy.Settings.Basher._removedHuntTarget = nil`n    Legacy.Settings.Basher.mobRoom = nil")
}
# Room mob flags can include x alongside m; IDs are keys, names are values.
$basher=[regex]::Replace($basher,'(?s)  (?:local function room_mob\(item\).*?\r?\n  )?function Legacy.Settings.Basher.Mobs\([^)]*\).*?(?=  registerAnonymousEventHandler\("gmcp.Char.Items.List")',@'
  local function room_mob(item)
    return type(item) == "table" and tostring(item.attrib or ""):find("m", 1, true) ~= nil
  end
  local function wanted_mob(item)
    if not room_mob(item) then return false end
    local name = tostring(item.name or ""):lower()
    local priorities = Legacy.Basher.Targets[gmcp.Room.Info.area] or {}
    return table.contains(priorities, name) and not table.contains(Legacy.Settings.Basher.Ignore, name)
  end
  local function live_room_mobs(refresh)
    local S = Legacy.Settings.Basher
    local room = tostring(gmcp.Room.Info.num or "")
    if refresh or S.mobRoom ~= room or type(S.roomMobs) ~= "table" then
      if S.mobRoom ~= room then S._removedHuntTarget = nil end
      S.roomMobs = {}
      S.mobRoom = room
      local list = gmcp.Char.Items and gmcp.Char.Items.List or {}
      local items = (not list.location or list.location == "room") and list.items or {}
      for _, item in pairs(items) do
        if room_mob(item) then S.roomMobs[tostring(item.id)] = item end
      end
    end
    return S.roomMobs
  end
  function Legacy.Settings.Basher.Mobs(event)
    local S = Legacy.Settings.Basher
    local list = gmcp.Char.Items and gmcp.Char.Items.List or {}
    if event == "gmcp.Char.Items.List" and list.location and list.location ~= "room" then return end
    S.possibleTargets = {}
    local items = live_room_mobs(event == "gmcp.Char.Items.List")
    for _, item in pairs(items) do
      if S.status == true and wanted_mob(item) then
        S.possibleTargets[tostring(item.id)] = item.name
      end
    end
  end

'@)
$basher=[regex]::Replace($basher,'(?s)  function Legacy.Settings.Basher.mobRemove\(\).*?(?=  registerAnonymousEventHandler\("gmcp.Char.Items.Remove")',@'
  function Legacy.Settings.Basher.mobRemove()
    local S = Legacy.Settings.Basher
    local removed = gmcp.Char.Items.Remove or {}
    if removed.location and removed.location ~= "room" then return end
    local item = removed.item or {}
    local id = tostring(item.id or "")
    live_room_mobs()[id] = nil
    local soulstorm = Legacy.Basher.Soulstorm
    if soulstorm and type(soulstorm.forget) == "function" then soulstorm.forget(id) end
    if S.status ~= true or not S.possibleTargets[id] then return end
    S.possibleTargets[id] = nil
    if tostring(S.currentTar or "") == id then
      S._removedHuntTarget = {id=id, name=tostring(item.name or ""), room=tostring(gmcp.Room.Info.num or "")}
      S.queued = false
      S.currentTar = ""
      if not tostring(item.name or ""):find("the corpse of", 1, true) then
        Legacy.bigEcho(tostring(item.name or id).." ran away!!!", "red", "gold")
      end
      Legacy.Basher.Target()
    end
  end

'@)
$basher=[regex]::Replace($basher,'(?s)  function Legacy.Settings.Basher.mobAdd\(\).*?(?=  registerAnonymousEventHandler\("gmcp.Char.Items.Add")',@'
  function Legacy.Settings.Basher.mobAdd()
    local S = Legacy.Settings.Basher
    local added = gmcp.Char.Items.Add or {}
    if added.location and added.location ~= "room" then return end
    local item = added.item or {}
    local id = tostring(item.id or "")
    if room_mob(item) and id ~= "" then live_room_mobs()[id] = item end
    if S.status == true and id ~= "" and wanted_mob(item) and not S.possibleTargets[id] then
      S.possibleTargets[id] = item.name
      Legacy.echo("<green>Added <gold>"..item.name.."<green> to possible targets")
      Legacy.Basher.Target()
    end
  end

'@)
$basher=[regex]::Replace($basher,'(?s) {2,4}function Legacy.Settings.Basher.mobCount\(\).*?(?=  registerAnonymousEventHandler\("gmcp.Char.Items")',@'
  function Legacy.Settings.Basher.mobCount()
    local mobs = 0
    local items = live_room_mobs()
    for _, item in pairs(items) do
      if room_mob(item) then mobs = mobs + 1 end
    end
    return mobs
  end

'@)
SetBody Script 'Basher' $basher
$toggle=$toggle.Replace('if soulstorm then', 'if soulstorm and type(soulstorm.begin) == "function" and type(soulstorm.stop) == "function" then')
$toggle=$toggle.Replace('if Legacy.Settings.Basher.status == false then','if Legacy.Settings.Basher.status ~= true then')
if(-not $toggle.Contains('Legacy.Settings.Basher.Mobs()')){
 $toggle=$toggle.Replace('  Legacy.Basher.Target()',"  Legacy.Settings.Basher.Mobs()`n  Legacy.Basher.Target()")
}
SetBody Alias 'Hunting Toggle' $toggle
SetBody Trigger 'Mob Slain' @'
if Legacy.Settings.Basher.status == true then
  local S = Legacy.Settings.Basher
  local slain = tostring(S.currentTar or "")
  local removed = S._removedHuntTarget
  local name = tostring(matches[2] or ""):lower()
  -- GMCP removal may select the successor before this slain line arrives.
  if removed and removed.room == tostring(gmcp.Room.Info.num or "") and removed.name:lower() == name then
    slain = removed.id
    S._removedHuntTarget = nil
  end
  local soulstorm = Legacy.Basher.Soulstorm
  if soulstorm and type(soulstorm.forget) == "function" then soulstorm.forget(slain) end
  if S.possibleTargets then S.possibleTargets[slain] = nil end
  if S.roomMobs then S.roomMobs[slain] = nil end
  S.lastTar = slain
  if tostring(S.currentTar or "") == slain then
    S.currentTar = ""
    S._attend = nil
    S.shield = false
    S.desc = ""
    S.queued = false
  end
  send('ql')
  local priorities = Legacy.Basher.Targets[gmcp.Room.Info.area]
  if not priorities then
    priorities = {}
    Legacy.Basher.Targets[gmcp.Room.Info.area] = priorities
  end
  if not table.contains(priorities, name) then
    table.insert(priorities, name)
    Legacy.echo("Added '<gold>"..matches[2].."<white>' to hunting targets in <gold>"..gmcp.Room.Info.area)
  end
  Legacy.Basher.Target()
end
'@
$body=[IO.File]::ReadAllText((Join-Path $root 'Apostate/hunting_soulstorm.lua'))
if($text.Contains('<name>Apostate hunting Soulstorm</name>')){SetBody Script 'Apostate hunting Soulstorm' $body}
else{
 $anchor=Entry Script 'Basher'
 $escaped=(Escape $body).Replace('&quot;','"').Replace('&apos;',"'")
 $block='<Script isActive="yes" isFolder="no"><name>Apostate hunting Soulstorm</name><packageName /><script>'+$escaped+'</script><eventHandlerList /></Script>'
 $text=$text.Insert($anchor.Index,$block+$newline)
}
$triggers=@(
 @('confirmed','^You call forth an unholy tide of necromantic essence and release it, engulfing (.+) in a profane soulstorm\.$'),
 @('already active',"^Necromantic essence still profanes (.+)'s soul\.$"),
 @('faded','^([A-Za-z][^:\r\n]*) steadies as the profane aura around (?:it|him|her|them) fades\.$')
)
foreach($row in $triggers){
 $name='Apostate Soulstorm '+$row[0]
 $script='local H=Legacy and Legacy.Basher and Legacy.Basher.Soulstorm; if H then H.note("'+$row[0]+'",matches[2]) end'
 $block='<Trigger isActive="yes" isFolder="no" isTempTrigger="no" isMultiline="no" isPerlSlashGOption="no" isColorizerTrigger="no" isFilterTrigger="no" isSoundTrigger="no" isColorTrigger="no" isColorTriggerFg="no" isColorTriggerBg="no"><name>'+$name+'</name><script>'+(Escape $script)+'</script><triggerType>0</triggerType><conditonLineDelta>0</conditonLineDelta><mStayOpen>0</mStayOpen><mCommand /><packageName /><mFgColor>#ff0000</mFgColor><mBgColor>#ffff00</mBgColor><mSoundFile /><colorTriggerFgColor>#000000</colorTriggerFgColor><colorTriggerBgColor>#000000</colorTriggerBgColor><regexCodeList><string>'+(Escape $row[1])+'</string></regexCodeList><regexCodePropertyList><integer>1</integer></regexCodePropertyList></Trigger>'
 if($text.Contains('<name>'+$name+'</name>')){
  $hit=Entry Trigger $name;$text=$text.Substring(0,$hit.Index)+$block+$text.Substring($hit.Index+$hit.Length)
 }else{
  $anchor=Entry Trigger 'Mob Slain';$text=$text.Insert($anchor.Index,$block+$newline)
 }
}
[void][xml]$text
if($PSCmdlet.ShouldProcess($PackagePath,'Embed Apostate Soulstorm startup and confirmation adapters')){
 [IO.File]::WriteAllText($PackagePath,$text,[Text.UTF8Encoding]::new($false))
}
