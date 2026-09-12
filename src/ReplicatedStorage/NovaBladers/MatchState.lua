--[[
	Shared arena availability — GameManager updates phase; MatchmakingService reads it.
]]

local MatchState = {
	phase = "Idle",
}

function MatchState.setPhase(phase)
	local previous = MatchState.phase
	MatchState.phase = phase or "Idle"
	if previous ~= "Idle" and MatchState.phase == "Idle" and MatchState.onAvailable then
		task.defer(MatchState.onAvailable)
	end
end

function MatchState.isAvailable()
	return MatchState.phase == "Idle"
end

function MatchState.getPhase()
	return MatchState.phase
end

return MatchState
