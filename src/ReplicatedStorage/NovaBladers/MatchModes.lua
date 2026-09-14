--[[
	MatchModes — Spielmodi für die Matchmaking-Queue.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		shortLabel = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		shortLabel = "1v1",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 45,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		shortLabel = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local byId = {}
for _, mode in MatchModes do
	byId[mode.id] = mode
end

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.all()
	return MatchModes
end

return MatchModes
