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

	MODE_ORDER = { "training", "pvp", "ffa" },
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingConfig.getRequiredCount(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	return mode and mode.minPlayers or 1
end

return MatchmakingConfig
