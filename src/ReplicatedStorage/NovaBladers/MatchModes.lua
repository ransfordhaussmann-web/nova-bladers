--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
]]

local modes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 45,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local MatchModes = {}

function MatchModes.get(modeId)
	return modes[modeId]
end

function MatchModes.all()
	local list = {}
	for _, mode in modes do
		table.insert(list, mode)
	end
	return list
end

return MatchModes
