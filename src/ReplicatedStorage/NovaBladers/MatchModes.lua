local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		maxPlayers = MatchmakingConfig.TRAINING_PLAYERS,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = MatchmakingConfig.PVP_PLAYERS,
		maxPlayers = MatchmakingConfig.PVP_PLAYERS,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = MatchmakingConfig.FFA_MIN_PLAYERS,
		maxPlayers = MatchmakingConfig.FFA_MAX_PLAYERS,
		fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	return { MatchModes.training, MatchModes.pvp, MatchModes.ffa }
end

return MatchModes
