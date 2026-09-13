local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchModes = {}

function MatchModes.get(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchModes.all()
	local list = {}
	for _, mode in MatchmakingConfig.MODES do
		table.insert(list, mode)
	end
	table.sort(list, function(a, b)
		return a.minPlayers < b.minPlayers
	end)
	return list
end

function MatchModes.recommendForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
