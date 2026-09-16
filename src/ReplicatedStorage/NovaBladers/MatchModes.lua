--[[
	MatchModes — player-count rules per queue mode.
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

local orderedIds = { "ffa", "pvp", "training" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getOrderedIds()
	return orderedIds
end

function MatchModes.isValid(modeId)
	return MatchModes[modeId] ~= nil
end

return MatchModes
