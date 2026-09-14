local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		maxPlayers = MatchmakingConfig.TRAINING_PLAYERS,
		instantStart = true,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = MatchmakingConfig.PVP_PLAYERS,
		maxPlayers = MatchmakingConfig.PVP_PLAYERS,
		instantStart = true,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = MatchmakingConfig.FFA_MIN_PLAYERS,
		maxPlayers = MatchmakingConfig.FFA_MAX_PLAYERS,
		fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getRecommended(playerCount)
	if playerCount >= MatchmakingConfig.FFA_MIN_PLAYERS then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
