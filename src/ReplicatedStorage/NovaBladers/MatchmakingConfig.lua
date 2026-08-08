local MatchmakingConfig = {
	QUEUES = {
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

	-- How often queue snapshots are pushed to clients (seconds)
	UPDATE_INTERVAL = 0.4,
}

function MatchmakingConfig.getQueue(modeId)
	return MatchmakingConfig.QUEUES[modeId]
end

function MatchmakingConfig.isValidMode(modeId)
	return MatchmakingConfig.QUEUES[modeId] ~= nil
end

return MatchmakingConfig
