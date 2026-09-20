local MatchModes = {
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
		instantStart = false,
	},
}

return MatchModes
