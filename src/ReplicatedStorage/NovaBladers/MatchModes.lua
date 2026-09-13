local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MODES = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		maxPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		instantStart = true,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = MatchmakingConfig.PVP_PLAYERS,
		maxPlayers = MatchmakingConfig.PVP_PLAYERS,
		instantStart = true,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = MatchmakingConfig.FFA_MIN,
		maxPlayers = MatchmakingConfig.FFA_MAX,
		instantStart = false,
	},
}

local MatchModes = {}

function MatchModes.get(modeId)
	return MODES[modeId]
end

function MatchModes.isValid(modeId)
	return MODES[modeId] ~= nil
end

function MatchModes.getMin(modeId)
	local mode = MODES[modeId]
	return mode and mode.minPlayers or 1
end

function MatchModes.getMax(modeId)
	local mode = MODES[modeId]
	return mode and mode.maxPlayers or 1
end

function MatchModes.all()
	local list = {}
	for _, mode in MODES do
		table.insert(list, mode)
	end
	return list
end

return MatchModes
