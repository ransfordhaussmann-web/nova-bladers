local MatchModes = {}

function MatchModes.getModeFromCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchModes.getLabel(modeId)
	if modeId == "ffa" then
		return "Modus: FFA"
	elseif modeId == "pvp" then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

function MatchModes.getLabelFromCount(count)
	return MatchModes.getLabel(MatchModes.getModeFromCount(count))
end

return MatchModes
