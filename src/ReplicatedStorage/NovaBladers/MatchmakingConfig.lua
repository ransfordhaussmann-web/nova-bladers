local MatchmakingConfig = {
	FFA_FILL_TIMEOUT = 12,
	QUEUE_BROADCAST_INTERVAL = 0.5,

	MODES = {
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
			minPlayers = 3,
			maxPlayers = 6,
			instantStart = false,
			fillTimeout = 12,
		},
	},
}

return MatchmakingConfig
