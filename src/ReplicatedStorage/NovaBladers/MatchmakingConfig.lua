local MatchmakingConfig = {
	-- Schnell-Match wählt Modus nach aktueller Server-Population
	RECOMMENDED_THRESHOLDS = {
		ffa = 3,
		pvp = 2,
	},

	-- Wie oft Queue-Status an Clients gesendet wird (Sekunden)
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Kurze Verzögerung vor Match-Start (Spieler sehen „Match bereit“)
	MATCH_READY_DELAY = 0.35,
}

return MatchmakingConfig
