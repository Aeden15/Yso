-- Auto-exported from Mudlet package script: Occie Random Generator
-- DO NOT EDIT IN XML; edit this file instead.

ak = ak or {}
ak.occie = ak.occie or {}
ak.occie.aura = ak.occie.aura or {}
ak.occie.aura.physical = ak.occie.aura.physical or 0
ak.occie.aura.mental = ak.occie.aura.mental or 0
ak.occie.aura.unknownparse = ak.occie.aura.unknownparse or {}

--akocciegen
--ak.occie.aura.physical
--ak.occie.aura.mental

local function _is_occultist()
	if Yso and Yso.classinfo and type(Yso.classinfo.is_occultist) == "function" then
		return Yso.classinfo.is_occultist()
	end
	return gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class == "Occultist"
end

function ak.occie.aura.parse_unnamable(count, who)
	ak.occie.aura.mental = ak.occie.aura.mental + count
	local addaffs = {"stupidity","dementia","confusion"}
	if count == 3 then
		for i = 1, #addaffs do
			if affstrack.score[addaffs[i]] > 0 then
				ak.ProTrackingConfirmed(addaffs[i])
        affstrack.score.stupidity = 100
        affstrack.score.dementia = 100
				affstrack.score.confusion = 100
				ak.scoreup(who or target)
				return
			end
		end
    affstrack.score.stupidity = 100
    affstrack.score.dementia = 100
		affstrack.score.confusion = 100
		ak.scoreup(who or target)
		return
	elseif count == 2 then
		if affstrack.score.stupidity == 100 then
			affstrack.score.confusion = 100
			affstrack.score.dementia = 100
		elseif affstrack.score.dementia == 100 then
			affstrack.score.stupidity = 100
			affstrack.score.confusion = 100
		elseif affstrack.score.confusion == 100 then
			affstrack.score.stupidity = 100
			affstrack.score.dementia = 100
		else

		end
		ak.scoreup(who or target)
		return
	elseif count == 1 then
		if affstrack.score.stupidity == 100 and affstrack.score.confusion == 100 then
			affstrack.score.dementia = 100
		elseif affstrack.score.stupidity == 100 and affstrack.score.dementia == 100 then
			affstrack.score.confusion = 100
		elseif affstrack.score.dementia == 100 and affstrack.score.confusion == 100 then
			affstrack.score.stupidity = 100
		else

		end
		ak.scoreup(who or target)
		return
 	end
end

function ak.occie.aura.parsereduct(what)
	if ak.backtracking then
		ak.backtracking = false
		return
	end
	if (gmcp.Char.Status.race or ""):match("Dragon") or not _is_occultist() then return end
	ak.occie.aura.mentalcures = {
    "focus",
    "argentum flake",
    "lobelia seed",
    "stannum flake",
    "prickly ash bark",
    "plumbum flake",
    "goldenseal root",
		"bellwort flower",
    "rage",
  }
	ak.occie.aura.physicalcures = {
    "piece of kelp",
		"bloodroot leaf",
    "magnesium chip",
    "aurum flake",
  }
  table.insert(ak.occie.aura.physicalcures,"ginseng root")
  table.insert(ak.occie.aura.physicalcures,"ferrum flake")
	ak.occie.aura.ignore = {"smoke","hawthorn berry","bayberry bark","calamine crystal",}
	if table.contains(ak.occie.aura.ignore, what) then return end
	if table.contains(ak.occie.aura.mentalcures,what) then
		ak.occie.aura.mental = ak.occie.aura.mental - 1
		if ak.occie.aura.mental < 0 then ak.occie.aura.mental = 0 end
	elseif table.contains(ak.occie.aura.physicalcures,what) then
		ak.occie.aura.physical = ak.occie.aura.physical - 1
		if ak.occie.aura.physical < 0 then ak.occie.aura.physical = 0 end
	elseif what == "treed" then
		ak.occie.aura.treed()
	elseif what == "passive" then
		ak.occie.aura.treed()
	elseif not table.contains(ak.occie.aura.unknownparse,what) then
		table.insert(ak.occie.aura.unknownparse, what)
	end
end

function ak.occie.aura.treed()
		ak.occie.aura.physical = ak.occie.aura.physical - 1
		if ak.occie.aura.physical < 0 then ak.occie.aura.physical = 0 end
end
