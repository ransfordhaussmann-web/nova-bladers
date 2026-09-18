--[[
	MatchModes — player-count rules per queue mode.
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
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getRecommended(serverPlayerCount)
	if serverPlayerCount >= 3 then
		return MatchModes.ffa
	elseif serverPlayerCount == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return MatchModes
