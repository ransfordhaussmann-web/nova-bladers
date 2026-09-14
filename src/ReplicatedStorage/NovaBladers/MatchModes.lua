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
		fillTimeout = true,
	},
}

local ordered = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.isValid(modeId)
	return MatchModes[modeId] ~= nil
end

function MatchModes.getRecommended(serverPlayerCount)
	if serverPlayerCount >= 3 then
		return "ffa"
	elseif serverPlayerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchModes.all()
	return ordered
end

return MatchModes
