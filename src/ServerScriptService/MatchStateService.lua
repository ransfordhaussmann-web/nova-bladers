local MatchStateService = {}

local arenaBusy = false
local activePlayers = {}
local onFreeCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in onFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

function MatchStateService.setActivePlayers(players)
	activePlayers = {}
	for _, player in players do
		activePlayers[player] = true
	end
end

function MatchStateService.isPlayerInMatch(player)
	return activePlayers[player] == true
end

function MatchStateService.clearActivePlayers()
	activePlayers = {}
end

return MatchStateService
