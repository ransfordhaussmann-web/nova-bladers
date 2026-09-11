local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchState = {}

function MatchState.getAutoModeId(playerCount)
	if playerCount >= MatchmakingConfig.AUTO_MODE_THRESHOLDS.ffa then
		return "ffa"
	elseif playerCount >= MatchmakingConfig.AUTO_MODE_THRESHOLDS.pvp then
		return "pvp"
	end
	return "training"
end

function MatchState.getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchState.isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

function MatchState.getRequiredPlayers(modeId)
	local config = MatchmakingConfig.MODES[modeId]
	return config and config.minPlayers or 1
end

function MatchState.getMaxPlayers(modeId)
	local config = MatchmakingConfig.MODES[modeId]
	return config and config.maxPlayers or 1
end

return MatchState
