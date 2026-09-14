local MatchmakingConfig = {
	FILL_TIMEOUT_FFA = 12,

	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			immediate = true,
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
			fillTimeout = 12,
		},
	},
}

return MatchmakingConfig
