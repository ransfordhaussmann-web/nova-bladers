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

	-- Portal / Quick-Match nutzen den aktiven Server-Modus (Training / PvP / FFA).
	QUICK_MATCH_USE_ACTIVE_MODE = true,
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

return MatchmakingConfig
