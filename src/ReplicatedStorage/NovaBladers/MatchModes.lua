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
	},
}

local ordered = { MatchModes.training, MatchModes.pvp, MatchModes.ffa }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getAll()
	return ordered
end

function MatchModes.isValid(modeId)
	return MatchModes[modeId] ~= nil
end

return MatchModes
