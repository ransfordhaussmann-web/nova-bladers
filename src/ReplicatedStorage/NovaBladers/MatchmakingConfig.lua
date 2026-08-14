local MatchmakingConfig = {
	SOLO_START_DELAY = 3,
	MAX_WAIT = 25,
	TICK_INTERVAL = 0.5,

	MIN_PLAYERS = {
		training = 1,
		pvp = 2,
		ffa = 3,
	},

	MODE_LABELS = {
		training = "Training",
		pvp = "1v1 PvP",
		ffa = "FFA",
	},

	MODE_DESCRIPTIONS = {
		training = "1 Spieler — Dummy-Gegner",
		pvp = "2 Spieler — Duell",
		ffa = "3+ Spieler — Free-for-All",
	},
}

return MatchmakingConfig
