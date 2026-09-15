--[[
	MatchStateService — tracks per-player queue membership and arena availability.
]]

local MatchStateService = {}

local playerQueue = {}
local arenaBusy = false
local pendingMatch = nil

function MatchStateService.getQueueMode(player)
	return playerQueue[player]
end

function MatchStateService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchStateService.setQueued(player, modeId)
	playerQueue[player] = modeId
end

function MatchStateService.clearPlayer(player)
	playerQueue[player] = nil
end

function MatchStateService.getPlayersInMode(modeId)
	local list = {}
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.setPendingMatch(payload)
	pendingMatch = payload
end

function MatchStateService.getPendingMatch()
	return pendingMatch
end

function MatchStateService.clearPendingMatch()
	pendingMatch = nil
end

return MatchStateService
