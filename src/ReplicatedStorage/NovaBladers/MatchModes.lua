local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		targetPlayers = 1,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		targetPlayers = 2,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
		targetPlayers = 6,
	},
}

function MatchModes.get(id)
	return MatchModes[id]
end

function MatchModes.getRecommended(serverPlayerCount)
	if serverPlayerCount >= 3 then
		return MatchModes.ffa
	elseif serverPlayerCount == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return MatchModes
