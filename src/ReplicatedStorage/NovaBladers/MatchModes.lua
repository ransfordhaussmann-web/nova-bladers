--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		instant = true,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		instant = true,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 2,
		maxPlayers = 6,
		instant = false,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	return MatchModes
end

return MatchModes
