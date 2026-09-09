local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			gatherDelay = 2,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
			gatherDelay = 3,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 6,
			gatherDelay = 3,
			fillTimeout = 12,
		},
	},

	QUEUE_UPDATE_INTERVAL = 0.5,
}

return MatchmakingConfig
