--[[
	MatchModes — Spielmodi für die Matchmaking-Queue.
	Training: Solo vs. Dummy | PvP: 1v1 | FFA: 3–6 Spieler
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 0,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local orderedIds = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getAll()
	local list = {}
	for _, id in orderedIds do
		table.insert(list, MatchModes[id])
	end
	return list
end

function MatchModes.resolveAuto(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
