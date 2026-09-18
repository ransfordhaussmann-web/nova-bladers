--[[
	MatchStateService — verfolgt ob die Arena belegt ist.
]]

local MatchStateService = {}

local arenaBusy = false
local idleCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.setIdle()
	arenaBusy = false
	for _, callback in idleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
