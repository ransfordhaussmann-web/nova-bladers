local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchModes = {
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
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT,
	},
}

return MatchModes
