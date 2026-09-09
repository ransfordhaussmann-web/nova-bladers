local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queuePayload(modeId)
	local mode = getMode(modeId)
	local queued = queues[modeId]
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queued,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeout = mode and mode.fillTimeout or 0,
		pending = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local payload = queuePayload(modeId)
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

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue == 0 then
		clearFillTimer(modeId)
	end

	if not silent then
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end

	if #queue == 0 then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
	return picked
end

local function tryStartMatch(modeId, forceStart)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if not forceStart and modeId == "ffa" and #queue < mode.maxPlayers and #queue >= mode.minPlayers then
		if not fillTimers[modeId] and mode.fillTimeout > 0 then
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				tryStartMatch(modeId, true)
			end)
			broadcastQueue(modeId)
		end
		return
	end

	clearFillTimer(modeId)

	local playerCount = math.min(#queue, mode.maxPlayers)
	if #queue < mode.minPlayers then
		return
	end

	local players = popPlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end

	if MatchmakingService.isQueued(player) then
		if playerQueue[player] == modeId then
			broadcastQueue(modeId)
			return true
		end
		removeFromQueue(player, true)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player)
	return true
end

function MatchmakingService.onMatchEnded()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player, true)
end

function MatchmakingService.getQueuePayload(modeId)
	return queuePayload(modeId)
end

return MatchmakingService
