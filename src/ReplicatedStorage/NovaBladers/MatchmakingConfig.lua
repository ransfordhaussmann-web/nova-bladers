local MatchmakingConfig = {
	-- Wie oft Queue-Status an wartende Clients gesendet wird
	QUEUE_BROADCAST_INTERVAL = 1,

	-- Kurze Verzögerung nach MatchEnde, bevor die nächste Queue startet
	POST_MATCH_COOLDOWN = 1.5,

	-- UI-Texte
	STATUS_SEARCHING = "Suche Gegner…",
	STATUS_PENDING = "Arena belegt — warte…",
	STATUS_READY = "Match startet…",
}

return MatchmakingConfig
