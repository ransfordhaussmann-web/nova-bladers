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
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local ordered = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getRecommended(playerCount)
	if playerCount >= 3 then
		return MatchModes.ffa
	end
	if playerCount == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

function MatchModes.getRecommendedId(playerCount)
	return MatchModes.getRecommended(playerCount).id
end

function MatchModes.all()
	local list = {}
	for _, id in ordered do
		table.insert(list, MatchModes[id])
	end
	return list
end

return MatchModes
