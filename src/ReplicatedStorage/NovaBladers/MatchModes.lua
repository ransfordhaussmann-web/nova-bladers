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
	return list
end

function MatchModes.isValid(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

return MatchModes
