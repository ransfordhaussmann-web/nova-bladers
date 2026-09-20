local MatchModes = {
	TRAINING = "training",
	PVP = "pvp",
	FFA = "ffa",
}

MatchModes.DEFS = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		instantStart = true,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		instantStart = true,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.get(modeId)
	return MatchModes.DEFS[modeId]
end

function MatchModes.isValid(modeId)
	return MatchModes.DEFS[modeId] ~= nil
end

function MatchModes.resolveAuto(playerCount)
	if playerCount >= 3 then
		return MatchModes.FFA
	end
	if playerCount == 2 then
		return MatchModes.PVP
	end
	return MatchModes.TRAINING
end

return MatchModes
