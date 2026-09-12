--[[
	MatchState — shared arena-busy flag between GameManager and MatchmakingService.
]]

local MatchState = {
	arenaBusy = false,
}

local freeCallbacks = {}

function MatchState.isArenaBusy()
	return MatchState.arenaBusy
end

function MatchState.setArenaBusy(busy)
	if MatchState.arenaBusy == busy then
		return
	end
	MatchState.arenaBusy = busy
	if not busy then
		for _, callback in freeCallbacks do
			task.defer(callback)
		end
	end
end

function MatchState.onArenaFree(callback)
	table.insert(freeCallbacks, callback)
end

return MatchState
