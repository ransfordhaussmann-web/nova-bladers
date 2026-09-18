local MatchStateService = {}

local isBusy = false
local idleCallbacks = {}

function MatchStateService.isBusy()
	return isBusy
end

function MatchStateService.setBusy()
	isBusy = true
end

function MatchStateService.setIdle()
	if not isBusy then
		return
	end
	isBusy = false
	for _, callback in idleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
