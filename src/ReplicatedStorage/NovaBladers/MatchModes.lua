--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local list = {
	MatchModes.training,
	MatchModes.pvp,
	MatchModes.ffa,
}

local byId = {}
for _, mode in list do
	byId[mode.id] = mode
end

MatchModes.list = list

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.isValid(modeId)
	return byId[modeId] ~= nil
end

return MatchModes
