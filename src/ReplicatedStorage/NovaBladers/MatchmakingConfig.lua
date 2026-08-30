local MatchmakingConfig = {
	QUEUES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			startDelay = 2,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
			startDelay = 4,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 8,
			startDelay = 5,
		},
	},

	QUEUE_ORDER = { "training", "pvp", "ffa" },
}

function MatchmakingConfig.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingConfig.getModeLabel(modeId)
	local cfg = MatchmakingConfig.QUEUES[modeId]
	return cfg and cfg.label or "Unbekannt"
end

return MatchmakingConfig
