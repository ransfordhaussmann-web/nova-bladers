local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			desc = "1 Spieler — Dummy-Gegner",
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = 0,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			desc = "2 Spieler — Duell",
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = 45,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			desc = "3–6 Spieler — Free-for-All",
			minPlayers = 3,
			maxPlayers = 6,
			fillTimeout = 12,
		},
	},

	QUEUE_UPDATE_INTERVAL = 1,
	MAX_WAIT_LABEL = "Warte auf Gegner…",
	PENDING_LABEL = "Arena belegt — du bist als Nächster dran",
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingConfig.getModeList()
	local list = {}
	for _, mode in MatchmakingConfig.MODES do
		table.insert(list, mode)
	end
	table.sort(list, function(a, b)
		return a.minPlayers < b.minPlayers
	end)
	return list
end

return MatchmakingConfig
