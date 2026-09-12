local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = nil,
			minPlayersOnTimeout = 1,
			priority = 1,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = nil,
			minPlayersOnTimeout = 2,
			priority = 2,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 6,
			fillTimeout = 12,
			minPlayersOnTimeout = 2,
			priority = 3,
		},
	},

	QUEUE_PRIORITY = { "training", "pvp", "ffa" },
}

function MatchmakingConfig.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingConfig
