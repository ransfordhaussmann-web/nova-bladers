local MatchStateService = {}

local arenaBusy = false
local idleCallbacks = {}

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in idleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
