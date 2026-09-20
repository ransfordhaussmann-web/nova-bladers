--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
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
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local ordered = { MatchModes.training, MatchModes.pvp, MatchModes.ffa }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	return ordered
end

function MatchModes.resolveQuickMatch(onlineCount)
	if onlineCount >= 3 then
		return "ffa"
	elseif onlineCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
