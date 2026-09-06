local MatchQueueConfig = {
	GATHER_DELAY = 2.5,
	SOLO_WAIT = 8,
	FFA_POP_DELAY = 1.0,

	MODE_LABELS = {
		training = "Training (1 Spieler)",
		pvp = "1v1 PvP (2 Spieler)",
		ffa = "FFA (3+ Spieler)",
	},

	MODE_TARGETS = {
		training = 1,
		pvp = 2,
		ffa = 3,
	},
}

return MatchQueueConfig
