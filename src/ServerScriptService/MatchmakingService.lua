local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local arenaBusy = false
local onMatchReady = nil
local onQueueUpdate = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {}, fillDeadline = nil }
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, p in queue.players do
			if p == player then
				table.remove(queue.players, i)
				break
			end
		end
		if #queue.players < MatchmakingConfig.MODES[modeId].minPlayers then
			queue.fillDeadline = nil
		end
	end

	playerMode[player] = nil
end

local function sendUpdate(player)
	if not onQueueUpdate then
		return
	end
	local modeId = playerMode[player]
	if not modeId then
		onQueueUpdate(player, MatchState.buildIdleUpdate())
		return
	end
	local queue = getQueue(modeId)
	onQueueUpdate(player, MatchState.buildQueueUpdate(
		player, modeId, #queue.players, arenaBusy, queue.fillDeadline
	))
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			sendUpdate(player)
		end
	end
end

local function canStart(modeId, queue)
	local mode = MatchmakingConfig.MODES[modeId]
	if #queue.players < mode.minPlayers then
		return false
	end
	if #queue.players >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end
	if modeId ~= "ffa" then
		return true
	end
	return false
end

local function popPlayers(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local queue = getQueue(modeId)
	local count = math.min(#queue.players, mode.maxPlayers)
	local players = {}
	for i = 1, count do
		table.insert(players, queue.players[i])
	end

	for i = count, 1, -1 do
		table.remove(queue.players, i)
	end
	queue.fillDeadline = nil

	for _, player in players do
		playerMode[player] = nil
	end

	return players
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
	if not busy then
		MatchmakingService.tick()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	local modeId = playerMode[player]
	removeFromQueue(player)
	sendUpdate(player)
	broadcastQueue(modeId)
end

function MatchmakingService.tryStart(modeId)
	if arenaBusy then
		return
	end

	local queue = getQueue(modeId)
	if not canStart(modeId, queue) then
		return
	end

	local players = popPlayers(modeId)
	for _, player in players do
		sendUpdate(player)
	end
	broadcastQueue(modeId)

	arenaBusy = true
	if onMatchReady then
		onMatchReady({ players = players, mode = modeId })
	end
end

function MatchmakingService.tick()
	if arenaBusy then
		return
	end

	for modeId, mode in MatchmakingConfig.MODES do
		local queue = getQueue(modeId)
		if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
			MatchmakingService.tryStart(modeId)
		elseif canStart(modeId, queue) then
			MatchmakingService.tryStart(modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

local wired = false

function MatchmakingService.configure(handlers)
	if handlers.onMatchReady then
		onMatchReady = handlers.onMatchReady
	end
	if handlers.onQueueUpdate then
		onQueueUpdate = handlers.onQueueUpdate
	end
end

local function ensureWired()
	if wired then
		return
	end
	wired = true

	local Remotes, Bindables = RemotesSetup.ensure()
	local HubService = require(script.Parent.HubService)

	if not onMatchReady then
		onMatchReady = function(payload)
			for _, player in payload.players do
				HubService.prepareForMatch(player)
			end
			Bindables.MatchReady:Fire(payload)
		end
	end

	if not onQueueUpdate then
		onQueueUpdate = function(player, update)
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, update)
			end
		end
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	local lastTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick >= MatchmakingConfig.QUEUE_TICK then
			lastTick = now
			MatchmakingService.tick()
		end
	end)
end

function MatchmakingService.init(handlers)
	MatchmakingService.configure(handlers or {})
	ensureWired()
end

function MatchmakingService.joinQueue(player, modeId)
	ensureWired()
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return false
	end

	MatchmakingService.leaveQueue(player)

	playerMode[player] = modeId
	local queue = getQueue(modeId)
	table.insert(queue.players, player)

	if modeId == "ffa" and #queue.players >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + mode.fillTimeout
	end

	sendUpdate(player)
	broadcastQueue(modeId)
	MatchmakingService.tryStart(modeId)
	return true
end

return MatchmakingService
