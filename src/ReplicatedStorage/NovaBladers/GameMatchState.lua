local GameMatchState = {
	phase = "Idle",
}

local idleCallbacks = {}

function GameMatchState.isBusy()
	return GameMatchState.phase ~= "Idle"
end

function GameMatchState.setPhase(phase)
	local wasBusy = GameMatchState.isBusy()
	GameMatchState.phase = phase
	if phase == "Idle" and wasBusy then
		for _, callback in idleCallbacks do
			task.defer(callback)
		end
	end
end

function GameMatchState.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return GameMatchState
