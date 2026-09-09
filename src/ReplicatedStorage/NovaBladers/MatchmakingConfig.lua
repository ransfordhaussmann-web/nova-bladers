local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = nil,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = nil,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 6,
			fillTimeout = 12,
		},
	},

	QUEUE_TICK_INTERVAL = 0.5,
	GATHER_DELAY = 1,
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingConfig.getModeList()
	local list = {}
	for _, mode in pairs(MatchmakingConfig.MODES) do
		table.insert(list, mode)
	end
	table.sort(list, function(a, b)
		return a.minPlayers < b.minPlayers
	end)
	return list
end

return MatchmakingConfig
