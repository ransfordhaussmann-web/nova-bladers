local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(modeId, status)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		players = names,
		count = #names,
		required = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, pendingStarts[modeId] and "pending" or "waiting")
	if not payload then
		return
	end

	for _, player in queues[modeId] do
		if player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, payload)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	local config = getModeConfig(modeId)
	if config and countQueue(modeId) < config.minPlayers then
		clearFillTimer(modeId)
		pendingStarts[modeId] = false
	end

	broadcastQueue(modeId)
	return modeId
end

local function extractPlayers(modeId, amount)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function tryStartMode(modeId)
	local config = getModeConfig(modeId)
	if not config or countQueue(modeId) < config.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueue(modeId)
		return
	end

	local playerCount = math.min(countQueue(modeId), config.maxPlayers)
	local players = extractPlayers(modeId, playerCount)
	if #players < config.minPlayers then
		for _, player in players do
			playerQueue[player] = modeId
			table.insert(queues[modeId], player)
		end
		return
	end

	clearFillTimer(modeId)
	pendingStarts[modeId] = false
	MatchStateService.setArenaBusy(true)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end

	for modeIdToUpdate in queues do
		broadcastQueue(modeIdToUpdate)
	end
end

local function ensureFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or config.fillTimeout <= 0 then
		return
	end
	if fillTimers[modeId] then
		return
	end
	if countQueue(modeId) < config.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(config.fillTimeout, function()
		fillTimers[modeId] = nil
		if countQueue(modeId) >= config.minPlayers then
			tryStartMode(modeId)
		end
	end)
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	if countQueue(modeId) >= getModeConfig(modeId).maxPlayers then
		return false, "queue_full"
	end

	playerQueue[player] = modeId
	table.insert(queue, player)
	broadcastQueue(modeId)

	local config = getModeConfig(modeId)
	if countQueue(modeId) >= config.minPlayers then
		if config.fillTimeout <= 0 or countQueue(modeId) >= config.maxPlayers then
			tryStartMode(modeId)
		else
			ensureFillTimer(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId and callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for modeId in queues do
		if pendingStarts[modeId] and countQueue(modeId) >= getModeConfig(modeId).minPlayers then
			pendingStarts[modeId] = false
			tryStartMode(modeId)
		else
			pendingStarts[modeId] = false
			broadcastQueue(modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

return MatchmakingService
