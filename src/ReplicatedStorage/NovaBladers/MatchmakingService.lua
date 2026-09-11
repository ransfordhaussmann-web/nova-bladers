local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchmakingService = {}

function MatchmakingService.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.buildQueuePayload(modeId, queueSize, status, extra)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return nil
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		playersInQueue = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		fillSecondsLeft = extra and extra.fillSecondsLeft,
	}
end

function MatchmakingService.buildIdlePayload()
	return { inQueue = false }
end

return MatchmakingService
