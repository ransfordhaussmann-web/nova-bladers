local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			desc = "1 Spieler — Dummy-Gegner",
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
			desc = "2 Spieler — Duell",
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 8,
			desc = "3+ Spieler — Free-for-All",
		},
	},

	-- Kurze Pause bevor ein vollständiger Lobby-Slot das Match startet
	MATCH_READY_DELAY = 2,

	-- Wie oft Warteschlangen-Status an Clients gesendet wird
	QUEUE_BROADCAST_INTERVAL = 0.5,
}

return MatchmakingConfig
