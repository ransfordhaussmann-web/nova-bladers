--[[
	MatchModes — queue definitions for Training, PvP, and FFA.
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
		minPlayers = 2,
		maxPlayers = 6,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getRecommended(playerCount)
	if playerCount >= 3 then
		return MatchModes.ffa
	elseif playerCount == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return MatchModes
