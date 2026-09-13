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

	-- Recommended mode when joining via portal / quick-match
	RECOMMEND_THRESHOLDS = {
		{ minCount = 3, mode = "ffa" },
		{ minCount = 2, mode = "pvp" },
		{ minCount = 1, mode = "training" },
	},
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingConfig.recommendMode(playerCount)
	for _, entry in MatchmakingConfig.RECOMMEND_THRESHOLDS do
		if playerCount >= entry.minCount then
			return entry.mode
		end
	end
	return "training"
end

return MatchmakingConfig
