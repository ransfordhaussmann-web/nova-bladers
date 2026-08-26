local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			gatherDelay = 0,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
			gatherDelay = 1.5,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 6,
			gatherDelay = 5,
		},
	},

	DEFAULT_MODE = "training",
	QUEUE_POLL_INTERVAL = 0.5,
}

return MatchmakingConfig
