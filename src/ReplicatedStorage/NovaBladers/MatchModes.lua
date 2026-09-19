--[[
	Match mode definitions for the matchmaking queue.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = nil,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = nil,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local orderedIds = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.isValid(modeId)
	return MatchModes[modeId] ~= nil
end

function MatchModes.getAllIds()
	return orderedIds
end

function MatchModes.resolveFromPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
