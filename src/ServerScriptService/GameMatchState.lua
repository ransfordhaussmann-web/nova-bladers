--[[
	GameMatchState — shared arena busy flag for matchmaking.
]]

local GameMatchState = {}

local arenaBusy = false
local onFreeCallbacks = {}

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy then
		for _, callback in onFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function GameMatchState.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

return GameMatchState
