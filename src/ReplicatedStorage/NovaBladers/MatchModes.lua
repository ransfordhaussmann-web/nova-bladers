local MatchModes = {}

local LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

function MatchModes.isValid(modeId)
	return LABELS[modeId] ~= nil
end

function MatchModes.getLabel(modeId)
	return LABELS[modeId] or modeId
end

function MatchModes.recommendForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
