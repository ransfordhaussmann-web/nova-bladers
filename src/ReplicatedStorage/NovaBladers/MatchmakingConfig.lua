local MatchmakingConfig = {
	-- Seconds to wait after minimum players are met before starting
	GATHER_BUFFER = 2,

	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxWait = 5,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxWait = 30,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxWait = 45,
			downgradeTo = "pvp",
			downgradeMin = 2,
		},
		quick = {
			id = "quick",
			label = "Quick Match",
			minPlayers = 1,
			maxWait = 8,
		},
	},

	-- Portal uses quick-match queue
	QUICK_MATCH_MODE = "quick",
}

return MatchmakingConfig
