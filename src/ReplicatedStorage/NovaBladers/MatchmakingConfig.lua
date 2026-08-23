local MatchmakingConfig = {
	-- Solo training starts after this wait if no opponents join
	SOLO_TRAINING_WAIT = 4,
	-- Brief pause before match flow begins (lets UI show "Match found")
	MATCH_FOUND_DELAY = 2,
	MAX_FFA_PLAYERS = 8,

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
			maxPlayers = 8,
		},
	},
}

return MatchmakingConfig
