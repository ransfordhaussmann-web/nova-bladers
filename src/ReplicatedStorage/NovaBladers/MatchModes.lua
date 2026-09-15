--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
]]

local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchModes = {
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
		minPlayers = MatchmakingConfig.FFA_MIN_PLAYERS,
		maxPlayers = MatchmakingConfig.FFA_MAX_PLAYERS,
		fillTimeout = MatchmakingConfig.FFA_FILL_TIMEOUT,
	},
}

local ordered = { MatchModes.training, MatchModes.pvp, MatchModes.ffa }

function MatchModes.get(id)
	return MatchModes[id]
end

function MatchModes.all()
	return ordered
end

function MatchModes.isValid(id)
	return MatchModes[id] ~= nil
end

return MatchModes
