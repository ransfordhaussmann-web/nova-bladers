--[[
	MatchmakingService — Queue-Verwaltung pro Modus, startet Matches via MatchReady.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueCount(modeId)
	return #ensureQueue(modeId)
end

local function isPlayerInList(list, player)
	for _, queued in list do
		if queued == player then
			return true
		end
	end
	return false
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = getQueueCount(modeId)
	local needed = mode.maxPlayers

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		playersNeeded = needed,
		minPlayers = mode.minPlayers,
		status = status or MatchmakingConfig.QUEUE_STATUS.WAITING,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueForMode(modeId)
	local queue = ensureQueue(modeId)
	local status = MatchStateService.isBusy()
		and MatchmakingConfig.QUEUE_STATUS.PENDING
		or MatchmakingConfig.QUEUE_STATUS.WAITING

	for _, player in queue do
		sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueForMode(modeId)
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	return picked
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and count >= mode.minPlayers and fillTimers[modeId] == nil then
		return true
	end
	return false
end

local function startMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or MatchStateService.isBusy() then
		return false
	end

	if not canStartMatch(modeId) then
		return false
	end

	local count = getQueueCount(modeId)
	local take = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, take)

	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(ensureQueue(modeId), player)
			playerQueue[player] = modeId
		end
		return false
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	MatchStateService.setBusy()

	for _, player in players do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			playersInQueue = #players,
			playersNeeded = mode.maxPlayers,
			minPlayers = mode.minPlayers,
			status = MatchmakingConfig.QUEUE_STATUS.STARTING,
		})
	end

	MatchReady:Fire(players, modeId)
	broadcastAllQueues()
	return true
end

local function tryStartAllQueues()
	for _, mode in MatchModes.all() do
		if canStartMatch(mode.id) then
			startMatch(mode.id)
		end
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartAllQueues()
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	if isPlayerInList(queue, player) then
		return true
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = MatchStateService.isBusy()
		and MatchmakingConfig.QUEUE_STATUS.PENDING
		or MatchmakingConfig.QUEUE_STATUS.WAITING
	sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	broadcastQueueForMode(modeId)

	scheduleFillTimer(modeId)
	tryStartAllQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueUpdate(player, { inQueue = false })
	broadcastQueueForMode(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	MatchStateService.onArenaFreed(function()
		broadcastAllQueues()
		tryStartAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
