local MatchStateService = {}

local inMatch = false
local freedCallbacks = {}

function MatchStateService.isBusy()
	return inMatch
end

function MatchStateService.setBusy(busy)
	if inMatch == busy then
		return
	end
	inMatch = busy
	if not busy then
		for _, callback in freedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(freedCallbacks, callback)
end

return MatchStateService
