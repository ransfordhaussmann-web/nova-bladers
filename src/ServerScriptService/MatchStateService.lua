--[[
	MatchStateService — Arena belegt / frei (für Queue-Pending).
]]

local MatchStateService = {
	_busy = false,
	_listeners = {},
}

function MatchStateService.isBusy()
	return MatchStateService._busy
end

function MatchStateService.setBusy(busy)
	if MatchStateService._busy == busy then
		return
	end
	MatchStateService._busy = busy
	for _, callback in MatchStateService._listeners do
		task.spawn(callback, busy)
	end
end

function MatchStateService.onChange(callback)
	table.insert(MatchStateService._listeners, callback)
end

return MatchStateService
