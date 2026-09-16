--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.list do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildUpdateForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { status = "idle" }
	end

	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	local pending = MatchStateService.isArenaBusy()

	local message
	if pending then
		message = string.format("Warten — Arena belegt (%s)", mode.label)
	else
		message = string.format("In Warteschlange: %s (%d/%d)", mode.label, size, mode.minPlayers)
	end

	return {
		status = if pending then "pending" else "queued",
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = size,
		requiredPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		message = message,
	}
end

local function broadcastQueueUpdate()
	for player, _ in pairs(playerQueue) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
		end
	end
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdateForPlayer(player))
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
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
	return picked
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate()
		return
	end

	if mode.fillTimeout and size < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	clearFillTimer(modeId)

	local takeCount = math.min(size, mode.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return
	end

	broadcastQueueUpdate()
	MatchReady:Fire(players, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end

	MatchmakingService.leaveQueue(player, false)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and getQueueSize(modeId) >= mode.minPlayers then
		startFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate()
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player, notify)
	local modeId = playerQueue[player]
	if not modeId then
		if notify then
			Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		end
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and mode.fillTimeout and getQueueSize(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if notify then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	end
	broadcastQueueUpdate()
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player, true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player, false)
	end)

	MatchStateService.onArenaFreed(function()
		for _, mode in MatchModes.list do
			MatchmakingService.tryStartMatch(mode.id)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
