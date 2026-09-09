--[[
	MatchStateService — tracks whether the arena is running a match.
	Shared by GameManager and MatchmakingService.
]]

local MatchStateService = {}

local isBusy = false
local onIdleCallbacks = {}

function MatchStateService.setBusy(busy)
	if isBusy == busy then
		return
	end
	isBusy = busy
	if not isBusy then
		for _, callback in onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return isBusy
end

function MatchStateService.onIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
