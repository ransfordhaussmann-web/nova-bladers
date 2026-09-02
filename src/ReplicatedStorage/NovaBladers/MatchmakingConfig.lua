local MatchmakingConfig = {
	MIN_PLAYERS = {
		training = 1,
		pvp = 2,
		ffa = 3,
	},

	MAX_QUEUE = 8,
	GATHER_SECONDS = 8,
	SOLO_TRAINING_WAIT = 10,

	MODE_LABELS = {
		training = "Training",
		pvp = "1v1 PvP",
		ffa = "FFA",
	},
}

return MatchmakingConfig
