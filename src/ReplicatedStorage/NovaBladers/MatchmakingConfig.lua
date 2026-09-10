local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			desc = "1 Spieler — Dummy-Gegner",
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = nil,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			desc = "2 Spieler — Duell",
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = nil,
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

	QUEUE_UPDATE_INTERVAL = 0.5,
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingConfig.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingConfig
