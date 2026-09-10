local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatches = {}
local arenaBusy = false

local callbacks = {}

function MatchmakingService.configure(handlers)
	callbacks = handlers or {}
	for modeId in pairs(handlers and handlers.modes or {}) do
		if not queues[modeId] then
			queues[modeId] = {
				players = {},
				fillToken = 0,
				fillScheduled = false,
			}
		end
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy then
		MatchmakingService.processPending()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

local function getModeConfig(modeId)
	return callbacks.getModeConfig and callbacks.getModeConfig(modeId)
end

local function getQueueSize(modeId)
	return #(queues[modeId] and queues[modeId].players or {})
end

local function buildQueuePayload(modeId, player, status)
	local mode = getModeConfig(modeId)
	local size = getQueueSize(modeId)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		players = size,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
		inQueue = true,
	}
end

local function notifyPlayer(player, payload)
	if callbacks.notifyPlayer then
		callbacks.notifyPlayer(player, payload)
	end
end

local function notifyQueue(modeId, status)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue.players do
		if player.Parent then
			notifyPlayer(player, buildQueuePayload(modeId, player, status))
		end
	end
end

local function clearFillTimer(modeId)
	local queue = queues[modeId]
	if queue then
		queue.fillToken += 1
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end
		local mode = getModeConfig(modeId)
		if mode and #queue.players < mode.minPlayers then
			queue.fillScheduled = false
			clearFillTimer(modeId)
		end
		notifyQueue(modeId, "waiting")
	end

	playerQueue[player] = nil
	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end
	return modeId
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	clearFillTimer(modeId)
	notifyQueue(modeId, "waiting")
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	if arenaBusy then
		table.insert(pendingMatches, {
			modeId = modeId,
			players = players,
		})
		for _, player in players do
			if player.Parent then
				notifyPlayer(player, buildQueuePayload(modeId, player, "pending"))
			end
		end
		return
	end

	arenaBusy = true
	for _, player in players do
		if player.Parent then
			notifyPlayer(player, buildQueuePayload(modeId, player, "starting"))
			if callbacks.onMatchReady then
				callbacks.onMatchReady(player, modeId)
			end
		end
	end

	if callbacks.startMatch then
		callbacks.startMatch(players, modeId)
	end
end

local function tryStartMode(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return
	end

	local size = #queue.players
	if size < mode.minPlayers then
		return
	end

	if size >= mode.maxPlayers then
		queue.fillScheduled = false
		clearFillTimer(modeId)
		startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		return
	end

	if modeId ~= "ffa" or not mode.fillTimeout then
		if size >= mode.minPlayers then
			queue.fillScheduled = false
			clearFillTimer(modeId)
			startMatch(modeId, takePlayers(modeId, size))
		end
		return
	end

	if size >= mode.minPlayers and not queue.fillScheduled then
		queue.fillScheduled = true
		clearFillTimer(modeId)
		queue.fillToken += 1
		local token = queue.fillToken
		notifyQueue(modeId, "filling")

		task.delay(mode.fillTimeout, function()
			if token ~= queue.fillToken then
				return
			end
			queue.fillScheduled = false
			local currentSize = #queue.players
			if currentSize >= mode.minPlayers then
				startMatch(modeId, takePlayers(modeId, currentSize))
			end
		end)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false, "invalid_player"
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	if not queues[modeId] then
		queues[modeId] = { players = {}, fillToken = 0, fillScheduled = false }
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	notifyPlayer(player, buildQueuePayload(modeId, player, "waiting"))
	notifyQueue(modeId, "waiting")
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	removeFromQueue(player)
	notifyPlayer(player, { inQueue = false })
	return true
end

function MatchmakingService.leaveAllQueues(player)
	if playerQueue[player] then
		removeFromQueue(player)
		notifyPlayer(player, { inQueue = false })
	end

	for i = #pendingMatches, 1, -1 do
		local pending = pendingMatches[i]
		for j, queuedPlayer in pending.players do
			if queuedPlayer == player then
				table.remove(pending.players, j)
				break
			end
		end
		if #pending.players == 0 then
			table.remove(pendingMatches, i)
		end
	end
end

function MatchmakingService.processPending()
	if arenaBusy or #pendingMatches == 0 then
		return
	end

	local nextMatch = table.remove(pendingMatches, 1)
	if nextMatch and #nextMatch.players > 0 then
		startMatch(nextMatch.modeId, nextMatch.players)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
