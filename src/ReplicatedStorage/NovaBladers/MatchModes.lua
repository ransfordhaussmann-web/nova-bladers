local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		maxPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		fillTimeout = nil,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = MatchmakingConfig.PVP_PLAYERS,
		maxPlayers = MatchmakingConfig.PVP_PLAYERS,
		fillTimeout = nil,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = MatchmakingConfig.FFA_MIN_PLAYERS,
		maxPlayers = MatchmakingConfig.FFA_MAX_PLAYERS,
		fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT,
	},
}

local MODE_IDS = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.isValid(modeId)
	for _, id in MODE_IDS do
		if id == modeId then
			return true
		end
	end
	return false
end

function MatchModes.all()
	return MODE_IDS
end

return MatchModes
