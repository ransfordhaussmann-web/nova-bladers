--[[
	MatchModes — player-count rules for Training, 1v1 PvP, and FFA queues.
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
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.resolveAuto(serverPlayerCount)
	if serverPlayerCount >= 3 then
		return "ffa"
	elseif serverPlayerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
