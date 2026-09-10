local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local updateCallbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function notifyUpdate()
	for _, callback in updateCallbacks do
		task.spawn(callback)
	end
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local list = queues[modeId]
	local count = #list
	local pending = MatchStateService.isBusy()
	local status = "waiting"

	if count >= mode.minPlayers then
		status = if pending then "pending" else "ready"
	end

	local fillRemaining = nil
	if fillTimers[modeId] then
		fillRemaining = math.max(0, fillTimers[modeId] - os.clock())
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillRemaining = fillRemaining,
	}
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getQueuePayload(modeId)
	return buildQueuePayload(modeId)
end

function MatchmakingService.getAllQueuePayloads()
	local payloads = {}
	for modeId in MatchmakingConfig.MODES do
		payloads[modeId] = buildQueuePayload(modeId)
	end
	return payloads
end

function MatchmakingService.getQueuedPlayers(modeId)
	local copy = {}
	for _, player in ipairs(queues[modeId]) do
		table.insert(copy, player)
	end
	return copy
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i, p in ipairs(list) do
		if p == player then
			table.remove(list, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] and #list < getMode(modeId).minPlayers then
		fillTimers[modeId] = nil
	end

	notifyUpdate()
end

function MatchmakingService.leave(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.buildPlayerUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local payload = buildQueuePayload(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		label = payload.label,
		count = payload.count,
		minPlayers = payload.minPlayers,
		maxPlayers = payload.maxPlayers,
		status = payload.status,
		fillRemaining = payload.fillRemaining,
	}
end

function MatchmakingService.join(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	local list = queues[modeId]
	if #list >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(list, player)
	playerQueue[player] = modeId

	if mode.fillTimeout and #list >= mode.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = os.clock() + mode.fillTimeout
	end

	notifyUpdate()
	return true
end

local function popBatch(modeId)
	local mode = getMode(modeId)
	local list = queues[modeId]
	local count = math.min(#list, mode.maxPlayers)
	if count < mode.minPlayers then
		return nil
	end

	local batch = {}
	for i = 1, count do
		local player = list[1]
		table.remove(list, 1)
		playerQueue[player] = nil
		table.insert(batch, player)
	end

	fillTimers[modeId] = nil
	notifyUpdate()
	return batch
end

local readyCallbacks = {}

function MatchmakingService.onMatchReady(callback)
	table.insert(readyCallbacks, callback)
end

function MatchmakingService.onQueueUpdate(callback)
	table.insert(updateCallbacks, callback)
end

local function fireReady(batch, modeId)
	for _, callback in readyCallbacks do
		task.spawn(callback, batch, modeId)
	end
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = getMode(modeId)
	local list = queues[modeId]
	if #list < mode.minPlayers then
		return false
	end

	if mode.fillTimeout then
		local deadline = fillTimers[modeId]
		if not deadline then
			return false
		end
		if #list < mode.maxPlayers and os.clock() < deadline then
			return false
		end
	end

	local batch = popBatch(modeId)
	if batch then
		MatchStateService.setBusy(true)
		fireReady(batch, modeId)
		return true
	end
	return false
end

function MatchmakingService.processQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.handleArenaFree()
	MatchmakingService.processQueues()
end

MatchStateService.onArenaFree(function()
	MatchmakingService.handleArenaFree()
end)

return MatchmakingService
