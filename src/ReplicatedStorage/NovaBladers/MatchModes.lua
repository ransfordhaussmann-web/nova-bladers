local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getRecommended(serverPlayerCount)
	if serverPlayerCount >= 3 then
		return "ffa"
	elseif serverPlayerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchModes.resolve(modeId, serverPlayerCount)
	if modeId == "auto" or modeId == nil then
		return MatchModes.getRecommended(serverPlayerCount)
	end
	return MatchModes.get(modeId) and modeId or MatchModes.getRecommended(serverPlayerCount)
end

return MatchModes
