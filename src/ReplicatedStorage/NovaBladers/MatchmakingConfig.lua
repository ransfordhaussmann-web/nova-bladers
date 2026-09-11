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
			fillTimeout = 12,
		},
	},

	-- Portal / Lobby-Button: Modus nach Server-Population
	AUTO_MODE_THRESHOLDS = {
		ffa = 3,
		pvp = 2,
	},

	QUEUE_UPDATE_INTERVAL = 1,
}

return MatchmakingConfig
