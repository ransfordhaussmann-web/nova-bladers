--[[
	Match mode definitions for the matchmaking queue.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 0,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local ordered = { MatchModes.training, MatchModes.pvp, MatchModes.ffa }

function MatchModes.get(id)
	return MatchModes[id]
end

function MatchModes.all()
	return ordered
end

function MatchModes.resolveAuto(playerCount)
	if playerCount >= 3 then
		return MatchModes.ffa
	elseif playerCount == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return MatchModes
