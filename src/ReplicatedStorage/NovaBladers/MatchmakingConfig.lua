local MatchmakingConfig = {
	MODES = {
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
			-- Start with 2 players after this many seconds if no third joins
			twoPlayerTimeout = 18,
		},
	},

	-- How often the server re-checks queues (FFA timeout, etc.)
	TICK_INTERVAL = 1,
}

return MatchmakingConfig
