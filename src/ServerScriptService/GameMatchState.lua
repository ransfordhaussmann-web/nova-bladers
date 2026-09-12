--[[
	GameMatchState — shared arena-busy flag for MatchmakingService and GameManager.
]]

local GameMatchState = {
	busy = false,
	phase = "Idle",
	onIdleCallbacks = {},
}

function GameMatchState.isBusy()
	return GameMatchState.busy
end

function GameMatchState.canStartMatch()
	return not GameMatchState.busy
end

function GameMatchState.setBusy(busy)
	GameMatchState.busy = busy
end

function GameMatchState.setPhase(phase)
	GameMatchState.phase = phase
	if phase == "Idle" then
		GameMatchState.busy = false
		for _, callback in GameMatchState.onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function GameMatchState.onIdle(callback)
	table.insert(GameMatchState.onIdleCallbacks, callback)
end

return GameMatchState
