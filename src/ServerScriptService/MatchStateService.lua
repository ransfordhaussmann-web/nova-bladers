--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local listeners = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy == true
	for _, listener in listeners do
		task.spawn(listener, arenaBusy)
	end
end

function MatchStateService.onChanged(listener)
	table.insert(listeners, listener)
	return function()
		for index, existing in listeners do
			if existing == listener then
				table.remove(listeners, index)
				break
			end
		end
	end
end

return MatchStateService
