--[[
	MatchModes — Spielmodi für die Matchmaking-Queue.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = nil,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = nil,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	return MatchModes
end

function MatchModes.ids()
	local ids = {}
	for key, mode in MatchModes do
		if typeof(mode) == "table" and mode.id then
			table.insert(ids, mode.id)
		end
	end
	return ids
end

return MatchModes
