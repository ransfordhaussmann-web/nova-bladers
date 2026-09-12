--[[
	MatchState — in-memory queue bookkeeping for MatchmakingService.
]]

local MatchState = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local pendingPlayers = {}
local ffaFillToken = 0

function MatchState.getQueues()
	return queues
end

function MatchState.getPlayerMode(player)
	return playerMode[player]
end

function MatchState.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchState.isPending(player)
	return pendingPlayers[player] == true
end

function MatchState.enqueue(player, modeId)
	local previous = playerMode[player]
	if previous and previous ~= modeId then
		MatchState.dequeue(player)
	end
	if playerMode[player] then
		return
	end

	playerMode[player] = modeId
	table.insert(queues[modeId], player)
end

function MatchState.dequeue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	pendingPlayers[player] = nil

	local queue = queues[modeId]
	for index = #queue, 1, -1 do
		if queue[index] == player then
			table.remove(queue, index)
			break
		end
	end
end

function MatchState.setPending(players)
	for player in pairs(pendingPlayers) do
		pendingPlayers[player] = nil
	end
	for _, player in players do
		pendingPlayers[player] = true
	end
end

function MatchState.clearPending(players)
	for _, player in players do
		pendingPlayers[player] = nil
	end
end

function MatchState.removePlayer(player)
	MatchState.dequeue(player)
end

function MatchState.bumpFfaFillToken()
	ffaFillToken += 1
	return ffaFillToken
end

function MatchState.getFfaFillToken()
	return ffaFillToken
end

function MatchState.snapshot(modeId)
	local queue = queues[modeId]
	local players = {}
	for _, player in queue do
		if player.Parent then
			table.insert(players, player)
		end
	end
	return players
end

function MatchState.buildUpdatePayload(player)
	local modeId = playerMode[player]
	local queue = modeId and queues[modeId] or nil
	local count = queue and #queue or 0
	local pending = pendingPlayers[player] == true

	return {
		queued = modeId ~= nil,
		modeId = modeId,
		position = modeId and count or 0,
		queueSize = count,
		pending = pending,
		arenaBusy = pending,
	}
end

return MatchState
