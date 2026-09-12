local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countQueue(modeId)
	local queue = queues[modeId]
	return queue and #queue or 0
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local queued = countQueue(modeId)
	local status = "waiting"
	if MatchState.isArenaBusy() then
		status = "pending"
	elseif queued >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = queued,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, player in queue do
		if player.Parent then
			local payload = buildQueuePayload(modeId, player)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if countQueue(modeId) < getMode(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

local function pullPlayers(modeId, amount)
	local queue = queues[modeId]
	if not queue then
		return {}
	end

	local picked = {}
	for _ = 1, math.min(amount, #queue) do
		local queuedPlayer = table.remove(queue, 1)
		if queuedPlayer and queuedPlayer.Parent then
			playerQueue[queuedPlayer] = nil
			table.insert(picked, queuedPlayer)
		end
	end
	return picked
end

local function restorePlayersToQueue(modeId, players)
	queues[modeId] = queues[modeId] or {}
	for _, queuedPlayer in players do
		if queuedPlayer.Parent and not playerQueue[queuedPlayer] then
			table.insert(queues[modeId], queuedPlayer)
			playerQueue[queuedPlayer] = modeId
		end
	end
end

local function startMatch(modeId)
	local mode = getMode(modeId)
	if not mode or MatchState.isArenaBusy() then
		return false
	end

	local queueSize = countQueue(modeId)
	if queueSize < mode.minPlayers then
		return false
	end

	local takeCount = math.min(queueSize, mode.maxPlayers)
	local players = pullPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		restorePlayersToQueue(modeId, players)
		return false
	end

	clearFillTimer(modeId)
	if not Bindables.MatchReady then
		restorePlayersToQueue(modeId, players)
		return false
	end
	Bindables.MatchReady:Fire(players, modeId)
	broadcastAllQueues()
	return true
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end
	if countQueue(modeId) < mode.minPlayers then
		return
	end
	if MatchState.isArenaBusy() then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		startMatch(modeId)
	end)
end

local function tryStartMode(modeId)
	local mode = getMode(modeId)
	if not mode or MatchState.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queueSize = countQueue(modeId)
	if queueSize >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if queueSize >= mode.minPlayers then
		if mode.fillTimeout then
			scheduleFillTimer(modeId)
		else
			startMatch(modeId)
		end
	end

	broadcastQueueUpdate(modeId)
end

local function tryStartAllModes()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	queues[modeId] = queues[modeId] or {}
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getActiveModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchState.onArenaFree(function()
		tryStartAllModes()
	end)
end

return MatchmakingService
