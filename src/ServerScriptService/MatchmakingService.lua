local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local pendingMatch = nil
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function countQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return 0
	end

	local total = 0
	for _, player in queues[modeId] do
		if player.Parent then
			total += 1
		end
	end
	return total
end

local function buildQueueSnapshot(modeId)
	local mode = getMode(modeId)
	local players = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(players, {
				userId = player.UserId,
				name = player.DisplayName,
			})
		end
	end

	return {
		mode = modeId,
		label = mode.label,
		players = players,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueueUpdate(modeId)
	if not callbacks.onQueueUpdate then
		return
	end

	local snapshot = buildQueueSnapshot(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			callbacks.onQueueUpdate(player, snapshot)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	broadcastQueueUpdate(modeId)
	return modeId
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	local count = countQueue(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout <= 0 then
		return count >= mode.minPlayers
	end
	return false
end

local fillTimers = {}

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if canStartMode(modeId) or countQueue(modeId) >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processPending()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId and callbacks.onPlayerLeft then
		callbacks.onPlayerLeft(player, modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if arenaBusy and pendingMatch then
		return false, "arena_busy"
	end

	MatchmakingService.leaveQueue(player)

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if countQueue(modeId) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if callbacks.onPlayerJoined then
		callbacks.onPlayerJoined(player, modeId, buildQueueSnapshot(modeId))
	end

	if countQueue(modeId) >= mode.minPlayers and mode.fillTimeout > 0 and countQueue(modeId) < mode.maxPlayers then
		startFillTimer(modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	local count = countQueue(modeId)
	if count < mode.minPlayers then
		return
	end

	local shouldStart = count >= mode.maxPlayers
	if not shouldStart and mode.fillTimeout <= 0 then
		shouldStart = count >= mode.minPlayers
	end
	if not shouldStart then
		return
	end

	local players = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(players, player)
		end
	end

	if #players < mode.minPlayers then
		return
	end

	clearFillTimer(modeId)

	local match = {
		mode = modeId,
		players = players,
	}

	if arenaBusy then
		pendingMatch = match
		for _, player in players do
			if callbacks.onQueuePending then
				callbacks.onQueuePending(player, match)
			end
		end
		return
	end

	MatchmakingService.startMatch(match)
end

function MatchmakingService.startMatch(match)
	for _, player in match.players do
		removeFromQueue(player)
	end

	pendingMatch = nil
	arenaBusy = true

	if callbacks.onMatchReady then
		callbacks.onMatchReady(match)
	end
end

function MatchmakingService.processPending()
	if arenaBusy or not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	MatchmakingService.tryStartMatch(match.mode)
end

function MatchmakingService.cancelStart(match)
	arenaBusy = false
	for _, player in match.players do
		if player.Parent and not playerQueue[player] then
			MatchmakingService.joinQueue(player, match.mode)
		end
	end
	MatchmakingService.processPending()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
