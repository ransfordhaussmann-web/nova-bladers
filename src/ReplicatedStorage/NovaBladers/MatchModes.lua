--[[
	MatchModes — queue mode definitions for Training, 1v1 PvP, and FFA.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		shortLabel = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = nil,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		shortLabel = "1v1",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = nil,
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

function MatchModes.isValid(modeId)
	return byId[modeId] ~= nil
end

return MatchModes
