local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local definitions = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		maxPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = MatchmakingConfig.PVP_PLAYERS,
		maxPlayers = MatchmakingConfig.PVP_PLAYERS,
		fillTimeout = 0,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3+ Spieler — Free-for-All",
		minPlayers = MatchmakingConfig.FFA_MIN_PLAYERS,
		maxPlayers = MatchmakingConfig.FFA_MAX_PLAYERS,
		fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT,
	},
}

local MatchModes = {}

function MatchModes.get(modeId)
	return definitions[modeId]
end

function MatchModes.all()
	return definitions
end

function MatchModes.getRecommended(serverPlayerCount)
	if serverPlayerCount >= MatchmakingConfig.FFA_MIN_PLAYERS then
		return definitions.ffa
	elseif serverPlayerCount == MatchmakingConfig.PVP_PLAYERS then
		return definitions.pvp
	end
	return definitions.training
end

return MatchModes
