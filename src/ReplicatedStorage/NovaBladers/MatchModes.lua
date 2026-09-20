--[[
	MatchModes — queue mode definitions for Training, PvP, and FFA.
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
		desc = "2–6 Spieler — Free-for-All",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local ordered = { MatchModes.training, MatchModes.pvp, MatchModes.ffa }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getAll()
	return ordered
end

function MatchModes.resolveAuto(playerCount)
	if playerCount >= 3 then
		return MatchModes.ffa
	end
	if playerCount == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return MatchModes
