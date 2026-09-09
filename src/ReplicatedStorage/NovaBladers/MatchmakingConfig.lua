local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			gatherDelay = 1,
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
			maxPlayers = 8,
			gatherDelay = 6,
		},
	},

	STATUS = {
		WAITING = "waiting",
		GATHERING = "gathering",
		PENDING_ARENA = "pendingArena",
	},
}

return MatchmakingConfig
