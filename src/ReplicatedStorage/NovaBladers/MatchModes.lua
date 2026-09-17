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
		minPlayers = 2,
		maxPlayers = 6,
	},
}

local byId = {}
local all = {}

for _, mode in MatchModes do
	if typeof(mode) == "table" and mode.id then
		byId[mode.id] = mode
		table.insert(all, mode)
	end
end

MatchModes.ALL = all

function MatchModes.get(id)
	return byId[id]
end

function MatchModes.isValid(id)
	return byId[id] ~= nil
end

function MatchModes.each(callback)
	for _, mode in all do
		callback(mode)
	end
end

return MatchModes
